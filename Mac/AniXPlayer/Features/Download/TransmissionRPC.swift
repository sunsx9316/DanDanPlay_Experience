//
//  TransmissionRPC.swift
//  AniXPlayer
//
//  macOS：Transmission RPC 客户端（无第三方依赖、不捆绑 BT 内核）。
//  仅包含 Foundation 逻辑，编入单元测试 target；密码只随请求发送，不写日志。
//

import Foundation

// MARK: - Configuration

struct TransmissionRPCConfiguration: Equatable {
    var host: String
    var port: Int
    var useHTTPS: Bool
    var rpcPath: String
    var username: String
    var password: String
    var sequentialDownload: Bool
    var timeout: TimeInterval

    init(
        host: String = "127.0.0.1",
        port: Int = 9091,
        useHTTPS: Bool = false,
        rpcPath: String = "/transmission/rpc",
        username: String = "",
        password: String = "",
        sequentialDownload: Bool = true,
        timeout: TimeInterval = 8
    ) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.port = (1...65535).contains(port) ? port : 9091
        self.useHTTPS = useHTTPS
        let path = rpcPath.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rpcPath = path.isEmpty ? "/transmission/rpc" : (path.hasPrefix("/") ? path : "/" + path)
        self.username = username
        self.password = password
        self.sequentialDownload = sequentialDownload
        self.timeout = max(1, timeout)
    }

    var rpcURL: URL {
        var input = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { input = "127.0.0.1" }

        let hasExplicitScheme = input.contains("://")
        let candidate = hasExplicitScheme ? input : "http://" + input
        if let parsed = URL(string: candidate), let parsedHost = parsed.host, !parsedHost.isEmpty {
            var components = URLComponents()
            if hasExplicitScheme {
                components.scheme = parsed.scheme ?? (useHTTPS ? "https" : "http")
            } else {
                components.scheme = useHTTPS ? "https" : "http"
            }
            components.host = parsedHost
            components.port = parsed.port ?? port
            let parsedPath = parsed.path
            components.path = (parsedPath.isEmpty || parsedPath == "/") ? rpcPath : parsedPath
            return components.url ?? fallbackRPCURL
        }
        return fallbackRPCURL
    }

    private var fallbackRPCURL: URL {
        var components = URLComponents()
        components.scheme = useHTTPS ? "https" : "http"
        components.host = "127.0.0.1"
        components.port = port
        components.path = rpcPath
        return components.url ?? URL(string: "http://127.0.0.1:9091/transmission/rpc")!
    }
}

// MARK: - Errors

enum TransmissionRPCError: LocalizedError, Equatable {
    case unavailable(String)
    case unauthorized
    case invalidResponse(String)
    case rpcFailure(String)
    case httpStatus(Int)
    case torrentFileUnreadable(String)
    case torrentFileDownload(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return NSLocalizedString(
                "未检测到 BT 内核，请安装 transmission-daemon 或在设置中配置 RPC。",
                comment: ""
            )
        case .unauthorized:
            return NSLocalizedString("BT 内核拒绝访问，请检查 RPC 用户名和密码。", comment: "")
        case .invalidResponse(let detail):
            return String(format: NSLocalizedString("BT 内核响应无效：%@", comment: ""), detail)
        case .rpcFailure(let message):
            return String(format: NSLocalizedString("BT 内核返回错误：%@", comment: ""), message)
        case .httpStatus(let status):
            return String(format: NSLocalizedString("BT 内核返回 HTTP %d", comment: ""), status)
        case .torrentFileUnreadable(let path):
            return String(format: NSLocalizedString("无法读取种子文件：%@", comment: ""), path)
        case .torrentFileDownload(let message):
            return String(format: NSLocalizedString("无法下载种子文件：%@", comment: ""), message)
        }
    }

    /// 连通性错误展示的统一文案（设置页与空态提示使用）。
    static var notDetectedMessage: String {
        NSLocalizedString(
            "未检测到 BT 内核，请安装 transmission-daemon 或在设置中配置 RPC。",
            comment: ""
        )
    }
}

// MARK: - RPC models

struct TransmissionSessionInfo: Equatable {
    var version: String
    var rpcVersion: Int
    var downloadDirectory: String?
}

enum TransmissionFilePriority: Int, CaseIterable, Equatable {
    case low = -1
    case normal = 0
    case high = 1

    var rpcKey: String {
        switch self {
        case .low:
            return "priority-low"
        case .normal:
            return "priority-normal"
        case .high:
            return "priority-high"
        }
    }

    var displayName: String {
        switch self {
        case .low:
            return NSLocalizedString("低", comment: "")
        case .normal:
            return NSLocalizedString("普通", comment: "")
        case .high:
            return NSLocalizedString("高", comment: "")
        }
    }
}

struct TransmissionTorrentFile: Equatable {
    var index: Int
    var name: String
    var length: Int64
    var bytesCompleted: Int64
    var isWanted: Bool
    var priority: Int

    var progress: Double {
        guard length > 0 else { return 0 }
        return min(max(Double(bytesCompleted) / Double(length), 0), 1)
    }
}

/// 全局限速与做种分享率（Transmission `session-set`）。0 表示不限制。
struct TransmissionTransferLimits: Equatable {
    var downloadKBps: Int
    var uploadKBps: Int
    var seedRatio: Double

    var arguments: [String: Any] {
        let download = max(0, downloadKBps)
        let upload = max(0, uploadKBps)
        let ratio = max(0, seedRatio)
        return [
            "speed-limit-down": download,
            "speed-limit-down-enabled": download > 0,
            "speed-limit-up": upload,
            "speed-limit-up-enabled": upload > 0,
            "seedRatioLimit": ratio,
            "seedRatioLimited": ratio > 0,
        ]
    }
}

struct TransmissionTorrent: Equatable {
    var id: Int
    var hashString: String
    var name: String
    var downloadDirectory: String?
    var percentDone: Double
    var rateDownload: Int64
    var rateUpload: Int64
    var eta: Int
    var status: Int
    var totalSize: Int64
    var leftUntilDone: Int64
    var isFinished: Bool
    var error: Int
    var errorString: String
    var files: [TransmissionTorrentFile]

    var hashKey: String {
        hashString.lowercased()
    }

    var downloadedBytes: Int64 {
        if totalSize > 0, leftUntilDone >= 0 {
            return min(totalSize, max(0, totalSize - leftUntilDone))
        }
        return files.reduce(0) { $0 + max(0, $1.bytesCompleted) }
    }

    var etaSeconds: Int? {
        eta > 0 ? eta : nil
    }

    var filePaths: [String] {
        let directory = downloadDirectory ?? ""
        return files.map { file in
            if file.name.hasPrefix("/") { return file.name }
            guard !directory.isEmpty else { return file.name }
            return URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent(file.name)
                .standardizedFileURL
                .path
        }
    }

    var fileProgress: [DownloadFileProgress] {
        let paths = filePaths
        return zip(files, paths).map { file, path in
            DownloadFileProgress(
                index: file.index,
                path: path,
                length: file.length,
                completedBytes: file.bytesCompleted,
                isWanted: file.isWanted,
                priority: file.priority
            )
        }
    }

    /// Transmission status: 0 stopped, 1/2 checking, 3/5 waiting, 4 downloading, 6 seeding.
    var isActivelyDownloading: Bool {
        status == 4 || status == 1 || status == 2
    }
}

struct TransmissionTorrentAddResult: Equatable {
    var id: Int
    var name: String
    var hashString: String
    var isDuplicate: Bool

    var engineTaskID: String {
        let hash = hashString.trimmingCharacters(in: .whitespacesAndNewlines)
        return hash.isEmpty ? String(id) : hash.lowercased()
    }
}

// MARK: - Client

final class TransmissionRPCClient {

    private let configuration: TransmissionRPCConfiguration
    private let session: URLSession
    private let lock = NSLock()
    private var sessionID: String?
    private var requestTag = 0

    init(configuration: TransmissionRPCConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = configuration.timeout
            config.timeoutIntervalForResource = configuration.timeout * 2
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.httpShouldSetCookies = false
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: High-level calls

    func sessionGet() async throws -> TransmissionSessionInfo {
        let args = try await call(method: "session-get")
        let version = Self.string(args, "version") ?? ""
        let rpcVersion = Self.int(args, "rpc-version") ?? 0
        return TransmissionSessionInfo(
            version: version.isEmpty ? "Transmission" : version,
            rpcVersion: rpcVersion,
            downloadDirectory: Self.string(args, "download-dir")
        )
    }

    /// 应用全局下载/上传限速与做种分享率。只有 RPC 成功返回才视为成功。
    func sessionSet(limits: TransmissionTransferLimits) async throws {
        _ = try await call(method: "session-set", arguments: limits.arguments)
    }

    /// `source` 为磁力链接；`.torrent` 使用 metainfo 版本。
    func addTorrent(
        source: String,
        savePath: String,
        sequentialDownload: Bool
    ) async throws -> TransmissionTorrentAddResult {
        var arguments: [String: Any] = [
            "filename": source,
            "download-dir": savePath,
            "paused": false
        ]
        if sequentialDownload {
            arguments["sequentialDownload"] = true
        }
        do {
            return try await addTorrent(arguments: arguments)
        } catch TransmissionRPCError.rpcFailure(let message) where sequentialDownload && Self.isUnsupportedSequentialMessage(message) {
            // 旧版 Transmission 可能不识别 sequentialDownload；回退并继续下载。
            arguments.removeValue(forKey: "sequentialDownload")
            return try await addTorrent(arguments: arguments)
        }
    }

    func addTorrent(
        metainfo: Data,
        savePath: String,
        sequentialDownload: Bool
    ) async throws -> TransmissionTorrentAddResult {
        var arguments: [String: Any] = [
            "metainfo": metainfo.base64EncodedString(),
            "download-dir": savePath,
            "paused": false
        ]
        if sequentialDownload {
            arguments["sequentialDownload"] = true
        }
        do {
            return try await addTorrent(arguments: arguments)
        } catch TransmissionRPCError.rpcFailure(let message)
            where sequentialDownload && Self.isUnsupportedSequentialMessage(message) {
            arguments.removeValue(forKey: "sequentialDownload")
            return try await addTorrent(arguments: arguments)
        }
    }

    func getTorrents(ids: [String]? = nil) async throws -> [TransmissionTorrent] {
        var arguments: [String: Any] = [
            "fields": [
                "id", "hashString", "name", "downloadDir", "percentDone",
                "rateDownload", "rateUpload", "eta", "status", "totalSize",
                "leftUntilDone", "isFinished", "error", "errorString", "files"
            ]
        ]
        if let ids, !ids.isEmpty {
            arguments["ids"] = ids
        }
        let result = try await call(method: "torrent-get", arguments: arguments)
        let list = Self.array(result, "torrents") ?? []
        return list.compactMap { item in
            guard let dictionary = item as? [String: Any] else { return nil }
            return TransmissionTorrent(dictionary: dictionary)
        }
    }

    func start(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        _ = try await call(method: "torrent-start", arguments: ["ids": ids])
    }

    func stop(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        _ = try await call(method: "torrent-stop", arguments: ["ids": ids])
    }

    func remove(ids: [String], deleteLocalData: Bool) async throws {
        guard !ids.isEmpty else { return }
        _ = try await call(
            method: "torrent-remove",
            arguments: ["ids": ids, "delete-local-data": deleteLocalData]
        )
    }

    /// `files-wanted` / `files-unwanted` 使用 torrent-get files 数组中的索引。
    func setFilesWanted(ids: [String], indices: [Int], wanted: Bool) async throws {
        guard !ids.isEmpty, !indices.isEmpty else { return }
        let key = wanted ? "files-wanted" : "files-unwanted"
        _ = try await call(
            method: "torrent-set",
            arguments: ["ids": ids, key: indices]
        )
    }

    /// `priority-high` / `priority-normal` / `priority-low` 使用 files 数组索引。
    func setFilePriorities(
        ids: [String],
        indices: [Int],
        priority: TransmissionFilePriority
    ) async throws {
        guard !ids.isEmpty, !indices.isEmpty else { return }
        _ = try await call(
            method: "torrent-set",
            arguments: ["ids": ids, priority.rpcKey: indices]
        )
    }

    // MARK: Request plumbing

    private func addTorrent(arguments: [String: Any]) async throws -> TransmissionTorrentAddResult {
        let result = try await call(method: "torrent-add", arguments: arguments)

        if let added = Self.dictionary(result, "torrent-added"),
           let addResult = Self.makeAddResult(from: added, isDuplicate: false) {
            return addResult
        }
        if let duplicate = Self.dictionary(result, "torrent-duplicate"),
           let addResult = Self.makeAddResult(from: duplicate, isDuplicate: true) {
            return addResult
        }
        throw TransmissionRPCError.invalidResponse("torrent-add 缺少 torrent-added/torrent-duplicate")
    }

    private func call(method: String, arguments: [String: Any] = [:]) async throws -> [String: Any] {
        var didRetrySession = false

        while true {
            let request = try makeRequest(method: method, arguments: arguments)
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw TransmissionRPCError.unavailable(error.localizedDescription)
            }

            guard let http = response as? HTTPURLResponse else {
                throw TransmissionRPCError.invalidResponse("非 HTTP 响应")
            }

            if http.statusCode == 409 {
                guard !didRetrySession else {
                    throw TransmissionRPCError.invalidResponse("Transmission session id 重试失败")
                }
                guard let newSessionID = http.value(forHTTPHeaderField: "X-Transmission-Session-Id"),
                      !newSessionID.isEmpty else {
                    throw TransmissionRPCError.invalidResponse("409 响应缺少 X-Transmission-Session-Id")
                }
                setSessionID(newSessionID)
                didRetrySession = true
                continue
            }

            if http.statusCode == 401 || http.statusCode == 403 {
                throw TransmissionRPCError.unauthorized
            }
            guard (200..<300).contains(http.statusCode) else {
                throw TransmissionRPCError.httpStatus(http.statusCode)
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw TransmissionRPCError.invalidResponse("响应不是 JSON 对象")
            }
            let result = Self.string(json, "result") ?? "success"
            guard result == "success" else {
                throw TransmissionRPCError.rpcFailure(result)
            }
            return Self.dictionary(json, "arguments") ?? [:]
        }
    }

    private func makeRequest(method: String, arguments: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: configuration.rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = configuration.timeout

        if let sessionID = currentSessionID(), !sessionID.isEmpty {
            request.setValue(sessionID, forHTTPHeaderField: "X-Transmission-Session-Id")
        }
        if !configuration.username.isEmpty || !configuration.password.isEmpty {
            let credentials = "\(configuration.username):\(configuration.password)"
            let encoded = Data(credentials.utf8).base64EncodedString()
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        }

        let tag = nextTag()
        let body: [String: Any] = [
            "method": method,
            "arguments": arguments,
            "tag": tag
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func currentSessionID() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return sessionID
    }

    private func setSessionID(_ value: String) {
        lock.lock()
        sessionID = value
        lock.unlock()
    }

    private func nextTag() -> Int {
        lock.lock()
        defer { lock.unlock() }
        requestTag += 1
        return requestTag
    }

    // MARK: Helpers

    private static func isUnsupportedSequentialMessage(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("invalid")
            || lower.contains("unknown")
            || lower.contains("unrecognized")
            || lower.contains("unexpected")
            || lower.contains("not supported")
    }

    private static func makeAddResult(
        from dictionary: [String: Any],
        isDuplicate: Bool
    ) -> TransmissionTorrentAddResult? {
        guard let id = int(dictionary, "id") else { return nil }
        return TransmissionTorrentAddResult(
            id: id,
            name: string(dictionary, "name") ?? "",
            hashString: string(dictionary, "hashString") ?? "",
            isDuplicate: isDuplicate
        )
    }

    static func string(_ dictionary: [String: Any], _ key: String) -> String? {
        dictionary[key] as? String
    }

    static func int(_ dictionary: [String: Any], _ key: String) -> Int? {
        if let value = dictionary[key] as? Int { return value }
        if let value = dictionary[key] as? NSNumber { return value.intValue }
        return nil
    }

    static func int64(_ dictionary: [String: Any], _ key: String) -> Int64? {
        if let value = dictionary[key] as? Int64 { return value }
        if let value = dictionary[key] as? NSNumber { return value.int64Value }
        return nil
    }

    static func double(_ dictionary: [String: Any], _ key: String) -> Double? {
        if let value = dictionary[key] as? Double { return value }
        if let value = dictionary[key] as? NSNumber { return value.doubleValue }
        return nil
    }

    static func bool(_ dictionary: [String: Any], _ key: String) -> Bool? {
        if let value = dictionary[key] as? Bool { return value }
        if let value = dictionary[key] as? NSNumber { return value.boolValue }
        return nil
    }

    static func array(_ dictionary: [String: Any], _ key: String) -> [Any]? {
        dictionary[key] as? [Any]
    }

    static func dictionary(_ dictionary: [String: Any], _ key: String) -> [String: Any]? {
        dictionary[key] as? [String: Any]
    }
}

// MARK: - TransmissionTorrent decoding

extension TransmissionTorrent {

    init?(dictionary: [String: Any]) {
        guard let id = TransmissionRPCClient.int(dictionary, "id"),
              let name = TransmissionRPCClient.string(dictionary, "name") else {
            return nil
        }

        let fileDictionaries = TransmissionRPCClient.array(dictionary, "files") ?? []
        let files: [TransmissionTorrentFile] = fileDictionaries.enumerated().compactMap { index, item in
            guard let file = item as? [String: Any],
                  let fileName = TransmissionRPCClient.string(file, "name") else {
                return nil
            }
            return TransmissionTorrentFile(
                index: index,
                name: fileName,
                length: TransmissionRPCClient.int64(file, "length") ?? 0,
                bytesCompleted: TransmissionRPCClient.int64(file, "bytesCompleted") ?? 0,
                isWanted: TransmissionRPCClient.bool(file, "isWanted") ?? true,
                priority: TransmissionRPCClient.int(file, "priority") ?? 0
            )
        }

        let totalSize = TransmissionRPCClient.int64(dictionary, "totalSize")
            ?? files.reduce(0) { $0 + $1.length }
        let isFinished = TransmissionRPCClient.bool(dictionary, "isFinished") ?? false
        let percentDone = min(
            max(
                TransmissionRPCClient.double(dictionary, "percentDone")
                    ?? (isFinished ? 1 : 0),
                0
            ),
            1
        )
        let leftUntilDone = TransmissionRPCClient.int64(dictionary, "leftUntilDone")
            ?? max(0, totalSize - Int64(Double(totalSize) * percentDone))

        self.init(
            id: id,
            hashString: TransmissionRPCClient.string(dictionary, "hashString") ?? "",
            name: name,
            downloadDirectory: TransmissionRPCClient.string(dictionary, "downloadDir"),
            percentDone: percentDone,
            rateDownload: TransmissionRPCClient.int64(dictionary, "rateDownload") ?? 0,
            rateUpload: TransmissionRPCClient.int64(dictionary, "rateUpload") ?? 0,
            eta: TransmissionRPCClient.int(dictionary, "eta") ?? -1,
            status: TransmissionRPCClient.int(dictionary, "status") ?? 0,
            totalSize: max(0, totalSize),
            leftUntilDone: max(0, leftUntilDone),
            isFinished: isFinished || percentDone >= 1,
            error: TransmissionRPCClient.int(dictionary, "error") ?? 0,
            errorString: TransmissionRPCClient.string(dictionary, "errorString") ?? "",
            files: files
        )
    }
}
