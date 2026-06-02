//
//  EmbyFileManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/29.
//

#if os(iOS) || os(tvOS)

import Foundation
import Alamofire
#if !os(tvOS)
import ANXLog
#else
import UIKit
#endif

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
            fetchItems(serverURL: serverURL, parentId: item.id, parent: directory, filterType: filterType, completion: completion)
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

        session.request(url, headers: authHeader()).responseData { [weak self] response in
            guard let self = self else { return }
            switch response.result {
            case .success(let data):
                if let itemsResponse = try? JSONDecoder().decode(EmbyItemsResponse.self, from: data) {
                    let rootFile = EmbyFile.rootFile
                    let files = itemsResponse.items.map { item in
                        let file = EmbyFile(item: item)
                        file.parentFile = rootFile
                        return file
                    }
                    ANX.logInfo(.HTTP, "[Emby] 获取媒体库视图成功, 数量: \(files.count)")
                    completion(.success(files))
                } else {
                    ANX.logInfo(.HTTP, "[Emby] /Views 解析失败，回退到 /Items")
                    self.fetchItems(serverURL: serverURL, parentId: nil, parent: EmbyFile.rootFile, filterType: nil, completion: completion)
                }
            case .failure(let error):
                ANX.logError(.HTTP, "[Emby] 获取媒体库视图失败: \(error)")
                completion(.failure(error))
            }
        }
    }

    private func fetchItems(serverURL: URL, parentId: String?, parent: File, filterType: URLFilterType?,
                            completion: @escaping ((Result<[File], Error>) -> Void)) {
        // Emby 没有独立的弹幕文件，不支持的类型直接返回空
        if let ft = filterType, !ft.contains(.video) && !ft.contains(.subtitle) {
            ANX.logInfo(.HTTP, "[Emby] 不支持的文件类型，返回空: \(ft.rawValue)")
            completion(.success([]))
            return
        }

        ANX.logInfo(.HTTP, "[Emby] 获取文件列表, parentId: \(parentId ?? "nil"), filterType: \(String(describing: filterType))")
        var queryItems = authQueryItems()

        let includeItemTypes: String = {
            guard let filterType = filterType else {
                return "Movie,Series,Episode,Season,BoxSet,Folder"
            }
            var types: [String] = []
            if filterType.contains(.video) || filterType.contains(.subtitle) {
                types.append(contentsOf: ["Movie", "Series", "Episode", "Season", "BoxSet", "Folder"])
            }
            return types.isEmpty ? "Movie,Series,Episode,Season,BoxSet,Folder" : types.joined(separator: ",")
        }()

        queryItems.append(contentsOf: [
            .init(name: "Recursive", value: "false"),
            .init(name: "IncludeItemTypes", value: includeItemTypes),
            .init(name: "Fields", value: "MediaSources,MediaStreams,Path"),
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
                    var allFiles: [File] = []
                    for item in itemsResponse.items {
                        let embyFile = EmbyFile(item: item)
                        embyFile.parentFile = parent
                        allFiles.append(embyFile)

                        // 从 MediaStreams 提取外部字幕，作为独立文件暴露（对齐 WebDAV/SMB 行为）
                        if let mediaSources = item.mediaSources {
                            for source in mediaSources {
                                guard let streams = source.mediaStreams else { continue }
                                for stream in streams where stream.isSubtitle && stream.isExternal {
                                    let subtitleFile = EmbyFile.EmbySubtitleFile(
                                        itemId: item.id,
                                        mediaSourceId: source.id,
                                        stream: stream
                                    )
                                    subtitleFile.parentFile = parent
                                    allFiles.append(subtitleFile)
                                }
                            }
                        }
                    }

                    // 根据 filterType 过滤
                    let files: [File]
                    if let ft = filterType {
                        files = allFiles.filter { file in
                            if ft.contains(.video) && !(file is EmbyFile.EmbySubtitleFile) { return true }
                            if ft.contains(.subtitle) && file is EmbyFile.EmbySubtitleFile { return true }
                            return false
                        }
                    } else {
                        files = allFiles
                    }

                    let subtitleCount = files.filter { $0 is EmbyFile.EmbySubtitleFile }.count
                    ANX.logInfo(.HTTP, "[Emby] 获取文件列表成功, 数量: \(files.count) (字幕: \(subtitleCount))")
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

    // MARK: - Subtitles

    func subtitlesOfMedia(_ file: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
        guard let file = file as? EmbyFile else {
            completion(.success([]))
            return
        }
        guard let mediaSources = file.embyItem?.mediaSources else {
            completion(.success([]))
            return
        }

        var subtitleFiles: [EmbyFile.EmbySubtitleFile] = []
        for source in mediaSources {
            guard let streams = source.mediaStreams else { continue }
            for stream in streams where stream.isSubtitle && stream.isExternal {
                let subtitleFile = EmbyFile.EmbySubtitleFile(
                    itemId: file.embyItem?.id ?? "",
                    mediaSourceId: source.id,
                    stream: stream
                )
                subtitleFile.parentFile = file.parentFile
                subtitleFiles.append(subtitleFile)
            }
        }
        ANX.logInfo(.HTTP, "[Emby] 找到字幕: \(subtitleFiles.count) 个")
        completion(.success(subtitleFiles))
    }

    func getSubtitleData(_ file: EmbyFile.EmbySubtitleFile, completion: @escaping ((Result<Data, Error>) -> Void)) {
        guard let serverURL = loginInfo?.url else {
            completion(.failure(EmbyError.notConnected))
            return
        }

        // 如果 Items API 已返回 deliveryUrl，直接下载
        if let deliveryUrlStr = file.deliveryUrl, !deliveryUrlStr.isEmpty,
           let deliveryURL = URL(string: deliveryUrlStr, relativeTo: serverURL)?.absoluteURL {
            ANX.logInfo(.HTTP, "[Emby] 使用 Items API 返回的 deliveryUrl: \(deliveryURL.absoluteString)")
            self.downloadSubtitle(from: deliveryURL, completion: completion)
            return
        }

        // 否则通过 PlaybackInfo 获取正确的字幕下载地址
        fetchSubtitleDeliveryUrl(itemId: file.itemId, mediaSourceId: file.mediaSourceId,
                                  streamIndex: file.streamIndex, format: file.codec,
                                  serverURL: serverURL) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let deliveryURL):
                ANX.logInfo(.HTTP, "[Emby] 字幕 PlaybackInfo deliveryUrl: \(deliveryURL.absoluteString)")
                self.downloadSubtitle(from: deliveryURL, completion: completion)
            case .failure(let error):
                ANX.logError(.HTTP, "[Emby] 获取字幕地址失败: \(error)")
                completion(.failure(error))
            }
        }
    }

    private func fetchSubtitleDeliveryUrl(itemId: String, mediaSourceId: String, streamIndex: Int,
                                           format: String, serverURL: URL,
                                           completion: @escaping ((Result<URL, Error>) -> Void)) {
        let path = "Items/\(itemId)/PlaybackInfo"
        let body: [String: String] = ["UserId": effectiveUserId()]
        let headers: HTTPHeaders = authHeader()

        guard let url = buildURL(serverURL, path: path, queryItems: authQueryItems()) else {
            completion(.failure(EmbyError.notConnected))
            return
        }

        ANX.logInfo(.HTTP, "[Emby] 请求 PlaybackInfo: \(url.absoluteString)")
        session.request(url, method: .post, parameters: body, encoder: JSONParameterEncoder.default, headers: headers)
            .responseData { [weak self] response in
                guard let self = self else { return }
                switch response.result {
                case .success(let data):
                    guard let info = try? JSONDecoder().decode(EmbyPlaybackInfoResponse.self, from: data) else {
                        ANX.logError(.HTTP, "[Emby] PlaybackInfo 解析失败")
                        completion(.failure(EmbyError.fileTypeError))
                        return
                    }
                    // 从 MediaSources 中找到对应 source，再从 MediaStreams 中找到字幕
                    for source in info.mediaSources {
                        guard let streams = source.mediaStreams else { continue }
                        for stream in streams where stream.isSubtitle && stream.index == streamIndex {
                            if let deliveryUrl = stream.deliveryUrl, !deliveryUrl.isEmpty {
                                if let url = URL(string: deliveryUrl, relativeTo: serverURL)?.absoluteURL {
                                    completion(.success(url))
                                    return
                                }
                            }
                        }
                    }
                    // deliveryUrl 为空时，构造 URL（关键：必须带格式扩展名 Stream.{format}）
                    let ext = format.isEmpty ? "srt" : format
                    let fallbackPath = "Videos/\(itemId)/\(mediaSourceId)/Subtitles/\(streamIndex)/Stream.\(ext)"
                    if let fallbackURL = self.buildURL(serverURL, path: fallbackPath, queryItems: self.authQueryItems()) {
                        ANX.logInfo(.HTTP, "[Emby] PlaybackInfo 无 deliveryUrl，拼接 URL: \(fallbackURL.absoluteString)")
                        completion(.success(fallbackURL))
                        return
                    }
                    ANX.logError(.HTTP, "[Emby] PlaybackInfo 中未找到字幕流")
                    completion(.failure(EmbyError.fileTypeError))

                case .failure(let error):
                    ANX.logError(.HTTP, "[Emby] PlaybackInfo 请求失败: \(error)")
                    completion(.failure(error))
                }
            }
    }

    private func downloadSubtitle(from url: URL, completion: @escaping ((Result<Data, Error>) -> Void)) {
        session.request(url, headers: authHeader()).responseData { response in
            let statusCode = response.response?.statusCode ?? 0
            guard statusCode == 200 else {
                let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
                ANX.logError(.HTTP, "[Emby] 字幕下载失败 HTTP \(statusCode): \(body.prefix(200))")
                completion(.failure(EmbyError.fileTypeError))
                return
            }
            guard let data = response.data, !data.isEmpty else {
                ANX.logError(.HTTP, "[Emby] 字幕数据为空")
                completion(.failure(EmbyError.fileTypeError))
                return
            }
            // 校验是否为文本格式（非 HTML 错误页）
            let header = String(data: data.prefix(512), encoding: .utf8) ?? ""
            if header.contains("<html") || header.contains("<!DOCTYPE") {
                ANX.logError(.HTTP, "[Emby] 字幕数据为 HTML 错误页: \(header.prefix(200))")
                completion(.failure(EmbyError.fileTypeError))
                return
            }
            ANX.logInfo(.HTTP, "[Emby] 字幕下载成功: \(data.count) bytes")
            completion(.success(data))
        }
    }

    // MARK: - Data

    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?,
                         completion: @escaping ((Result<Data, Error>) -> Void)) {
        if let subtitleFile = file as? EmbyFile.EmbySubtitleFile {
            getSubtitleData(subtitleFile, completion: completion)
            return
        }

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
