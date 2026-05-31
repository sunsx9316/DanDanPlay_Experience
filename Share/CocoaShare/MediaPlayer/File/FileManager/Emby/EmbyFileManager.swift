//
//  EmbyFileManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/29.
//

#if os(iOS) || os(tvOS)

import Foundation
import Alamofire
import ANXLog

class EmbyFileManager: FileManagerProtocol {

    private enum EmbyError: LocalizedError {
        case fileTypeError
        case authFailed
        case notConnected

        var errorDescription: String? {
            switch self {
            case .fileTypeError: return "文件类型错误"
            case .authFailed: return "认证失败"
            case .notConnected: return "未连接服务器"
            }
        }
    }

    var desc: String {
        return NSLocalizedString("Emby", comment: "")
    }

    var addressExampleDesc: String {
        return "服务器地址：http://example:8096"
    }

    var passwordDesc: String {
        return NSLocalizedString("API Key", comment: "")
    }

    static let shared = EmbyFileManager()

    private(set) var loginInfo: LoginInfo?

    private var accessToken: String?
    private var userId: String?

    private lazy var session: Session = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return Session(configuration: config)
    }()

    // MARK: - Connect

    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping ((Error?) -> Void)) {
        ANX.logInfo(.HTTP, "[Emby] 开始连接: \(loginInfo.url.absoluteString)")
        if let apiKey = loginInfo.auth?.apiKey, !apiKey.isEmpty {
            connectWithAPIKey(apiKey, serverURL: loginInfo.url, loginInfo: loginInfo, completionHandler: completionHandler)
        } else {
            connectWithUsername(loginInfo, completionHandler: completionHandler)
        }
    }

    private func connectWithAPIKey(_ apiKey: String, serverURL: URL, loginInfo: LoginInfo,
                                    completionHandler: @escaping ((Error?) -> Void)) {
        ANX.logInfo(.HTTP, "[Emby] 使用 API Key 模式认证")
        let infoURL = serverURL.appendingPathComponent("System/Info")
        var components = URLComponents(url: infoURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [.init(name: "api_key", value: apiKey)]

        guard let requestURL = components?.url else {
            completionHandler(EmbyError.authFailed)
            return
        }

        session.request(requestURL).responseData { [weak self] response in
            guard let self = self else { return }
            switch response.result {
            case .success:
                ANX.logInfo(.HTTP, "[Emby] System/Info 验证成功，获取用户ID...")
                self.loginInfo = loginInfo
                self.accessToken = nil
                self.fetchUserId(serverURL: serverURL, completionHandler: completionHandler)
            case .failure(let error):
                ANX.logError(.HTTP, "[Emby] System/Info 验证失败: \(error)")
                completionHandler(error)
            }
        }
    }

    private func connectWithUsername(_ loginInfo: LoginInfo,
                                      completionHandler: @escaping ((Error?) -> Void)) {
        ANX.logInfo(.HTTP, "[Emby] 使用用户名+密码模式认证")
        let serverURL = loginInfo.url
        let password = loginInfo.auth?.password ?? ""

        guard !password.isEmpty else {
            completionHandler(EmbyError.authFailed)
            return
        }

        let authURL = serverURL.appendingPathComponent("Users/AuthenticateByName")
        let body: [String: String] = [
            "Username": loginInfo.auth?.userName ?? "",
            "Pw": password
        ]
        let headers: HTTPHeaders = ["X-Emby-Authorization": embyAuthorizationHeader()]

        session.request(authURL, method: .post, parameters: body, encoder: JSONParameterEncoder.default, headers: headers)
            .responseData { [weak self] response in
                guard let self = self else { return }
                switch response.result {
                case .success(let data):
                    if let authResponse = try? JSONDecoder().decode(EmbyAuthResponse.self, from: data) {
                        self.loginInfo = loginInfo
                        self.accessToken = authResponse.accessToken
                        self.userId = authResponse.user.id
                        ANX.logInfo(.HTTP, "[Emby] 用户名认证成功, userId: \(authResponse.user.id)")
                        completionHandler(nil)
                    } else {
                        let statusCode = response.response?.statusCode ?? 0
                        let body = String(data: data, encoding: .utf8) ?? "nil"
                        ANX.logError(.HTTP, "[Emby] 用户名认证失败: HTTP \(statusCode), body: \(body)")
                        completionHandler(EmbyError.authFailed)
                    }
                case .failure(let error):
                    ANX.logError(.HTTP, "[Emby] 用户名认证请求失败: \(error)")
                    completionHandler(error)
                }
            }
    }

    // MARK: - Browse

    func contentsOfDirectory(at directory: File, filterType: URLFilterType?,
                             completion: @escaping ((Result<[File], Error>) -> Void)) {
        guard let directory = directory as? EmbyFile else {
            completion(.failure(EmbyError.fileTypeError))
            return
        }

        guard let serverURL = loginInfo?.url else {
            completion(.failure(EmbyError.notConnected))
            return
        }

        if directory == EmbyFile.rootFile {
            // 根目录：列出媒体库视图
            fetchUserViews(serverURL: serverURL, completion: completion)
        } else if let item = directory.embyItem, item.isFolder {
            // 文件夹：列出子内容
            fetchItems(serverURL: serverURL, parentId: item.id, filterType: filterType, completion: completion)
        } else {
            completion(.success([]))
        }
    }

    private func fetchUserViews(serverURL: URL, completion: @escaping ((Result<[File], Error>) -> Void)) {
        ANX.logInfo(.HTTP, "[Emby] 获取用户媒体库视图...")
        let queryItems = authQueryItems()
        let path = "Users/\(effectiveUserId())/Views"
        guard let url = buildURL(serverURL, path: path, queryItems: queryItems) else {
            completion(.failure(EmbyError.notConnected))
            return
        }

        session.request(url, headers: authHeader()).responseData { response in
            switch response.result {
            case .success(let data):
                if let itemsResponse = try? JSONDecoder().decode(EmbyItemsResponse.self, from: data) {
                    let files = itemsResponse.items.map { EmbyFile(item: $0) }
                    ANX.logInfo(.HTTP, "[Emby] 获取媒体库视图成功, 数量: \(files.count)")
                    completion(.success(files))
                } else {
                    ANX.logInfo(.HTTP, "[Emby] /Views 解析失败，回退到 /Items")
                    self.fetchItems(serverURL: serverURL, parentId: nil, filterType: nil, completion: completion)
                }
            case .failure(let error):
                ANX.logError(.HTTP, "[Emby] 获取媒体库视图失败: \(error)")
                completion(.failure(error))
            }
        }
    }

    private func fetchItems(serverURL: URL, parentId: String?, filterType: URLFilterType?,
                            completion: @escaping ((Result<[File], Error>) -> Void)) {
        ANX.logInfo(.HTTP, "[Emby] 获取文件列表, parentId: \(parentId ?? "nil")")
        var queryItems = authQueryItems()
        queryItems.append(contentsOf: [
            .init(name: "Recursive", value: "false"),
            .init(name: "IncludeItemTypes", value: "Movie,Series,Episode,Season,BoxSet,Folder"),
            .init(name: "Fields", value: "MediaSources,Path"),
        ])
        if let parentId = parentId {
            queryItems.append(.init(name: "ParentId", value: parentId))
        }

        let path = "Users/\(effectiveUserId())/Items"
        guard let url = buildURL(serverURL, path: path, queryItems: queryItems) else {
            completion(.failure(EmbyError.notConnected))
            return
        }

        session.request(url, headers: authHeader()).responseData { response in
            switch response.result {
            case .success(let data):
                if let itemsResponse = try? JSONDecoder().decode(EmbyItemsResponse.self, from: data) {
                    let files = itemsResponse.items.map { EmbyFile(item: $0) }
                    ANX.logInfo(.HTTP, "[Emby] 获取文件列表成功, 数量: \(files.count)")
                    completion(.success(files))
                } else {
                    ANX.logInfo(.HTTP, "[Emby] 获取文件列表成功但解析为空")
                    completion(.success([]))
                }
            case .failure(let error):
                ANX.logError(.HTTP, "[Emby] 获取文件列表失败: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Data

    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?,
                         completion: @escaping ((Result<Data, Error>) -> Void)) {
        guard let file = file as? EmbyFile else {
            completion(.failure(EmbyError.fileTypeError))
            return
        }

        var headers = authHeader()
        if let range = range {
            headers.add(name: "Range", value: "bytes=\(range.lowerBound)-\(range.upperBound)")
        }

        session.request(file.streamURL, headers: headers).responseData { response in
            switch response.result {
            case .success(let data):
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }.downloadProgress { p in
            progress?(p.fractionCompleted)
        }
    }

    func deleteFile(_ file: File, completionHandler: @escaping ((Error?) -> Void)) {
        completionHandler(EmbyError.fileTypeError)
    }

    func pickFiles(_ directory: File?, from viewController: ANXViewController, filterType: URLFilterType?,
                   completion: @escaping ((Result<[File], Error>) -> Void)) {
        assert(false, "不支持")
    }

    // MARK: - Helpers

    private func authQueryItem() -> URLQueryItem? {
        if let apiKey = loginInfo?.auth?.apiKey {
            return .init(name: "api_key", value: apiKey)
        } else if let token = accessToken {
            return .init(name: "api_key", value: token)
        }
        return nil
    }

    func streamURL(for itemId: String) -> URL {
        guard let serverURL = loginInfo?.url else {
            return URL(fileURLWithPath: "/")
        }
        let url = serverURL.appendingPathComponent("Videos/\(itemId)/stream")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            .init(name: "Static", value: "true")
        ]
        if let authItem = authQueryItem() {
            queryItems.append(authItem)
        }
        components?.queryItems = queryItems
        return components?.url ?? url
    }

    private func embyAuthorizationHeader() -> String {
        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "AniXPlayer"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let deviceName = UIDevice.current.name
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        return "MediaBrowser Client=\"\(appName)\", Device=\"\(deviceName)\", DeviceId=\"\(deviceId)\", Version=\"\(version)\""
    }

    func coverImageURL(for item: EmbyItem?) -> URL? {
        guard let item = item,
              let tag = item.primaryImageTag,
              let serverURL = loginInfo?.url else { return nil }

        let url = serverURL.appendingPathComponent("Items/\(item.id)/Images/Primary")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            .init(name: "maxHeight", value: "200"),
            .init(name: "tag", value: tag),
        ]
        if let authItem = authQueryItem() {
            queryItems.append(authItem)
        }
        components?.queryItems = queryItems
        return components?.url
    }

    private func fetchUserId(serverURL: URL, completionHandler: @escaping ((Error?) -> Void)) {
        // API Key 模式下先尝试 /Users/Me，失败则回退到 /Users 列表
        let meURL = serverURL.appendingPathComponent("Users/Me")
        var meComponents = URLComponents(url: meURL, resolvingAgainstBaseURL: false)
        meComponents?.queryItems = authQueryItems()
        guard let meRequestURL = meComponents?.url else {
            completionHandler(nil)
            return
        }
        session.request(meRequestURL, headers: authHeader()).responseData { [weak self] userResponse in
            guard let self = self else { return }
            if let data = userResponse.data,
               let user = try? JSONDecoder().decode(EmbyUser.self, from: data) {
                self.userId = user.id
                ANX.logInfo(.HTTP, "[Emby] 通过 /Users/Me 获取 userId 成功: \(user.id)")
                completionHandler(nil)
            } else {
                ANX.logInfo(.HTTP, "[Emby] /Users/Me 失败，回退到 /Users")
                self.fetchUsersList(serverURL: serverURL, completionHandler: completionHandler)
            }
        }
    }

    private func fetchUsersList(serverURL: URL, completionHandler: @escaping ((Error?) -> Void)) {
        let usersURL = serverURL.appendingPathComponent("Users")
        var components = URLComponents(url: usersURL, resolvingAgainstBaseURL: false)
        components?.queryItems = authQueryItems()
        guard let requestURL = components?.url else {
            completionHandler(nil)
            return
        }
        session.request(requestURL, headers: authHeader()).responseData { [weak self] response in
            guard let self = self else { return }
            if let data = response.data,
               let users = try? JSONDecoder().decode([EmbyUser].self, from: data),
               let firstUser = users.first {
                self.userId = firstUser.id
                ANX.logInfo(.HTTP, "[Emby] 通过 /Users 获取 userId 成功: \(firstUser.id)")
            } else {
                let statusCode = response.response?.statusCode ?? 0
                let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
                ANX.logError(.HTTP, "[Emby] 获取用户列表失败: HTTP \(statusCode), body: \(body)")
            }
            completionHandler(nil)
        }
    }

    private func effectiveUserId() -> String {
        return userId ?? "me"
    }

    private func authQueryItems() -> [URLQueryItem] {
        if accessToken == nil, let apiKey = loginInfo?.auth?.apiKey {
            return [.init(name: "api_key", value: apiKey)]
        }
        return []
    }

    private func authHeader() -> HTTPHeaders {
        var headers: HTTPHeaders = ["X-Emby-Authorization": embyAuthorizationHeader()]
        if let token = accessToken {
            headers.add(name: "X-Emby-Token", value: token)
        } else if let apiKey = loginInfo?.auth?.apiKey {
            headers.add(name: "X-Emby-Token", value: apiKey)
        }
        return headers
    }

    private func buildURL(_ serverURL: URL, path: String, queryItems: [URLQueryItem] = []) -> URL? {
        let url = serverURL.appendingPathComponent(path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = queryItems
        // auth query items that weren't already added
        let authItems = authQueryItems()
        for authItem in authItems {
            if !items.contains(where: { $0.name == authItem.name }) {
                items.append(authItem)
            }
        }
        components?.queryItems = items.isEmpty ? nil : items
        return components?.url
    }
}

#endif
