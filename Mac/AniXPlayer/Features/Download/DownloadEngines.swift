//
//  DownloadEngines.swift
//  AniXPlayer
//
//  macOS：下载引擎抽象与两个实现。
//  - HTTPDownloadEngine：URLSessionDownloadTask（可暂停/恢复）
//  - TransmissionRPCEngine：连接本机 transmission-daemon（不捆绑 BT 内核）
//

import Foundation

// MARK: - Update / protocol

struct DownloadTaskUpdate {
    var taskID: UUID
    var kind: DownloadTaskKind
    var title: String?
    var status: DownloadTaskStatus
    var progress: Double
    var downloadedBytes: Int64
    var totalBytes: Int64
    var downloadSpeed: Int64
    var uploadSpeed: Int64
    var etaSeconds: Int?
    var errorMessage: String?
    var engineTaskID: String?
    var filePaths: [String]
    var isStreaming: Bool
    var streamPath: String?
}

protocol DownloadEngine: AnyObject {
    func add(task: DownloadTask) async throws -> String?
    func start(task: DownloadTask) async throws
    func pause(task: DownloadTask) async throws
    func stop(task: DownloadTask) async throws
    func remove(task: DownloadTask, deleteFiles: Bool) async throws
    func refresh(tasks: [DownloadTask]) async throws -> [DownloadTaskUpdate]
}

enum DownloadEngineError: LocalizedError {
    case invalidURL(String)
    case btDisabled
    case unsupportedSource(String)
    case directoryUnavailable(String)
    case fileOperation(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return String(format: NSLocalizedString("下载地址无效：%@", comment: ""), value)
        case .btDisabled:
            return NSLocalizedString("BT 集成已在设置中关闭，无法添加磁力/种子任务。", comment: "")
        case .unsupportedSource(let value):
            return String(format: NSLocalizedString("不支持的下载来源：%@", comment: ""), value)
        case .directoryUnavailable(let path):
            return String(format: NSLocalizedString("无法访问保存目录：%@", comment: ""), path)
        case .fileOperation(let message):
            return String(format: NSLocalizedString("文件操作失败：%@", comment: ""), message)
        case .httpStatus(let status):
            return String(format: NSLocalizedString("服务器返回 HTTP %d", comment: ""), status)
        }
    }
}

// MARK: - HTTP engine

final class HTTPDownloadEngine: NSObject, DownloadEngine, URLSessionDownloadDelegate {

    /// 主线程回调。
    var onUpdate: (([DownloadTaskUpdate]) -> Void)?

    private final class Activity {
        let taskID: UUID
        var sourceURL: URL
        var saveDirectory: URL
        var securityScopedURL: URL?
        var status: DownloadTaskStatus = .queued
        var progress: Double = 0
        var downloadedBytes: Int64 = 0
        var totalBytes: Int64 = 0
        var speed: Int64 = 0
        var etaSeconds: Int?
        var errorMessage: String?
        var filePaths: [String] = []
        var title: String
        var meter = DownloadSpeedMeter()
        var sessionTask: URLSessionDownloadTask?
        var pauseRequested = false
        var stopRequested = false
        var lastPublished = Date.distantPast
        var lastProgressAt = Date.distantPast

        init(task: DownloadTask, sourceURL: URL, saveDirectory: URL, securityScopedURL: URL?) {
            self.taskID = task.id
            self.sourceURL = sourceURL
            self.saveDirectory = saveDirectory
            self.securityScopedURL = securityScopedURL
            self.title = task.displayTitle
        }
    }

    private let lock = NSLock()
    private var activities: [UUID: Activity] = [:]
    private let delegateQueue: OperationQueue
    private var session: URLSession!

    override init() {
        delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.name = "com.anixplayer.download.http"
        super.init()

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 7 * 24 * 3600
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    }

    deinit {
        session.invalidateAndCancel()
    }

    var activeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activities.values.filter { $0.status == .downloading && $0.sessionTask != nil }.count
    }

    // MARK: Protocol

    func add(task: DownloadTask) async throws -> String? {
        guard let url = Self.validHTTPURL(task.source) else {
            throw DownloadEngineError.invalidURL(task.source)
        }
        _ = url
        return nil
    }

    func start(task: DownloadTask) async throws {
        guard let url = Self.validHTTPURL(task.source) else {
            throw DownloadEngineError.invalidURL(task.source)
        }

        let access = DownloadFileAccess.resolveDirectory(
            path: task.savePath,
            bookmark: task.savePathBookmark
        )
        do {
            try FileManager.default.createDirectory(at: access.url, withIntermediateDirectories: true)
        } catch {
            access.securityScopedURL?.stopAccessingSecurityScopedResource()
            throw DownloadEngineError.directoryUnavailable(task.savePath)
        }

        let resumeURL = Self.resumeDataURL(for: task.id)
        let resumeData = try? Data(contentsOf: resumeURL)

        lock.lock()
        let activity: Activity
        var oldTask: URLSessionDownloadTask?

        if let existing = activities[task.id] {
            activity = existing
            oldTask = existing.sessionTask
            existing.sessionTask = nil
            existing.securityScopedURL?.stopAccessingSecurityScopedResource()
            existing.securityScopedURL = access.securityScopedURL
            existing.saveDirectory = access.url
            existing.sourceURL = url
        } else {
            activity = Activity(
                task: task,
                sourceURL: url,
                saveDirectory: access.url,
                securityScopedURL: access.securityScopedURL
            )
            activities[task.id] = activity
        }

        activity.status = .downloading
        activity.pauseRequested = false
        activity.stopRequested = false
        activity.errorMessage = nil
        activity.speed = 0
        activity.etaSeconds = nil
        activity.meter.reset()
        activity.lastProgressAt = .distantPast

        let downloadTask: URLSessionDownloadTask
        if let resumeData, !resumeData.isEmpty {
            downloadTask = session.downloadTask(withResumeData: resumeData)
        } else {
            downloadTask = session.downloadTask(with: url)
        }
        downloadTask.taskDescription = task.id.uuidString
        activity.sessionTask = downloadTask
        let update = makeUpdate(activity)
        lock.unlock()

        if let resumeData, !resumeData.isEmpty {
            try? FileManager.default.removeItem(at: resumeURL)
        }
        oldTask?.cancel()
        downloadTask.resume()
        deliver([update])
    }

    func pause(task: DownloadTask) async throws {
        var target: URLSessionDownloadTask?
        var update: DownloadTaskUpdate?

        lock.lock()
        if let activity = activities[task.id] {
            activity.pauseRequested = true
            activity.stopRequested = false
            activity.status = .paused
            activity.speed = 0
            activity.etaSeconds = nil
            target = activity.sessionTask
            update = makeUpdate(activity)
        }
        lock.unlock()

        if let target {
            if #available(macOS 14.0, *) {
                target.cancel(byProducingResumeData: { [weak self] data in
                    guard let self, let data, !data.isEmpty else { return }
                    self.lock.lock()
                    let shouldWrite = self.activities[task.id]?.status == .paused
                    self.lock.unlock()
                    if shouldWrite {
                        Self.writeResumeData(data, for: task.id)
                    }
                })
            } else {
                target.cancel()
            }
        } else {
            Self.removeResumeData(for: task.id)
        }
        if let update {
            deliver([update])
        }
    }

    func stop(task: DownloadTask) async throws {
        var target: URLSessionDownloadTask?
        var update: DownloadTaskUpdate?

        lock.lock()
        if let activity = activities[task.id] {
            activity.pauseRequested = false
            activity.stopRequested = true
            activity.status = .stopped
            activity.speed = 0
            activity.etaSeconds = nil
            target = activity.sessionTask
            update = makeUpdate(activity)
        }
        lock.unlock()

        Self.removeResumeData(for: task.id)
        target?.cancel()
        if let update {
            deliver([update])
        }
    }

    func remove(task: DownloadTask, deleteFiles: Bool) async throws {
        var target: URLSessionDownloadTask?
        var scoped: URL?
        var paths: [String] = []

        lock.lock()
        if let activity = activities.removeValue(forKey: task.id) {
            target = activity.sessionTask
            scoped = activity.securityScopedURL
            paths = activity.filePaths
        }
        lock.unlock()

        target?.cancel()
        Self.removeResumeData(for: task.id)
        scoped?.stopAccessingSecurityScopedResource()

        if deleteFiles {
            let fileManager = FileManager.default
            for path in Set(paths) where fileManager.fileExists(atPath: path) {
                try? fileManager.removeItem(atPath: path)
            }
        }
    }

    func refresh(tasks: [DownloadTask]) async throws -> [DownloadTaskUpdate] {
        lock.lock()
        defer { lock.unlock() }
        return tasks.compactMap { task in
            activities[task.id].map { makeUpdate($0) }
        }
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let taskID = taskID(from: downloadTask) else { return }

        var update: DownloadTaskUpdate?
        lock.lock()
        if let activity = activities[taskID],
           activity.sessionTask?.taskIdentifier == downloadTask.taskIdentifier {
            activity.status = .downloading
            activity.downloadedBytes = totalBytesWritten
            if totalBytesExpectedToWrite > 0 {
                activity.totalBytes = totalBytesExpectedToWrite
            } else {
                activity.totalBytes = max(activity.totalBytes, totalBytesWritten)
            }
            activity.progress = activity.totalBytes > 0
                ? min(max(Double(totalBytesWritten) / Double(activity.totalBytes), 0), 1)
                : 0

            let now = Date()
            activity.lastProgressAt = now
            activity.speed = activity.meter.record(totalBytes: totalBytesWritten, at: now)
            if activity.speed > 0, activity.totalBytes > totalBytesWritten {
                let remaining = Double(activity.totalBytes - totalBytesWritten)
                activity.etaSeconds = Int(ceil(remaining / Double(activity.speed)))
            } else {
                activity.etaSeconds = nil
            }

            if now.timeIntervalSince(activity.lastPublished) >= 0.25 {
                activity.lastPublished = now
                update = makeUpdate(activity)
            }
        }
        lock.unlock()

        if let update {
            deliver([update])
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let taskID = taskID(from: downloadTask) else { return }

        var update: DownloadTaskUpdate?
        var scopedToRelease: URL?

        lock.lock()
        guard let activity = activities[taskID],
              activity.sessionTask?.taskIdentifier == downloadTask.taskIdentifier else {
            lock.unlock()
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: activity.saveDirectory,
                withIntermediateDirectories: true
            )
            if let http = downloadTask.response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw DownloadEngineError.httpStatus(http.statusCode)
            }
            let response = downloadTask.response
            let contentDisposition = (response as? HTTPURLResponse)?
                .value(forHTTPHeaderField: "Content-Disposition")
            let preferredName = DownloadFileName.fileName(fromContentDisposition: contentDisposition)
                ?? response?.suggestedFilename.map { DownloadFileName.sanitize($0) }
                ?? DownloadFileName.fileName(from: activity.sourceURL)
                ?? "download"
            let destination = DownloadFileName.uniqueURL(
                in: activity.saveDirectory,
                preferredName: preferredName
            )

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)

            let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?
                .int64Value ?? activity.downloadedBytes
            activity.status = .completed
            activity.progress = 1
            activity.downloadedBytes = size
            activity.totalBytes = size
            activity.speed = 0
            activity.etaSeconds = nil
            activity.errorMessage = nil
            activity.filePaths = [destination.path]
            activity.sessionTask = nil
            scopedToRelease = activity.securityScopedURL
            activity.securityScopedURL = nil
            update = makeUpdate(activity)
        } catch {
            activity.status = .failed
            activity.errorMessage = error.localizedDescription
            activity.speed = 0
            activity.etaSeconds = nil
            activity.sessionTask = nil
            scopedToRelease = activity.securityScopedURL
            activity.securityScopedURL = nil
            update = makeUpdate(activity)
        }
        lock.unlock()

        Self.removeResumeData(for: taskID)
        scopedToRelease?.stopAccessingSecurityScopedResource()
        if let update {
            deliver([update])
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let taskID = taskID(from: task) else { return }

        var update: DownloadTaskUpdate?
        var scopedToRelease: URL?

        lock.lock()
        guard let activity = activities[taskID],
              activity.sessionTask?.taskIdentifier == task.taskIdentifier else {
            lock.unlock()
            return
        }

        if let error {
            if activity.pauseRequested {
                activity.status = .paused
                if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    Self.writeResumeData(resumeData, for: taskID)
                }
            } else if activity.stopRequested {
                activity.status = .stopped
            } else {
                activity.status = .failed
                activity.errorMessage = error.localizedDescription
                if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    Self.writeResumeData(resumeData, for: taskID)
                }
            }
            activity.speed = 0
            activity.etaSeconds = nil
        } else if activity.status != .completed {
            activity.status = .failed
            activity.errorMessage = NSLocalizedString("下载完成但未找到输出文件", comment: "")
        }

        activity.sessionTask = nil
        activity.pauseRequested = false
        activity.stopRequested = false
        scopedToRelease = activity.securityScopedURL
        activity.securityScopedURL = nil
        update = makeUpdate(activity)
        lock.unlock()

        scopedToRelease?.stopAccessingSecurityScopedResource()
        if let update {
            deliver([update])
        }
    }

    // MARK: Helpers

    private func taskID(from task: URLSessionTask) -> UUID? {
        guard let value = task.taskDescription else { return nil }
        return UUID(uuidString: value)
    }

    private func makeUpdate(_ activity: Activity) -> DownloadTaskUpdate {
        let stalled = activity.status == .downloading
            && Date().timeIntervalSince(activity.lastProgressAt) > 3
        return DownloadTaskUpdate(
            taskID: activity.taskID,
            kind: .http,
            title: nil,
            status: activity.status,
            progress: activity.progress,
            downloadedBytes: activity.downloadedBytes,
            totalBytes: activity.totalBytes,
            downloadSpeed: stalled ? 0 : activity.speed,
            uploadSpeed: 0,
            etaSeconds: stalled ? nil : activity.etaSeconds,
            errorMessage: activity.errorMessage,
            engineTaskID: nil,
            filePaths: activity.filePaths,
            isStreaming: false,
            streamPath: nil
        )
    }

    private func deliver(_ updates: [DownloadTaskUpdate]) {
        guard !updates.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(updates)
        }
    }

    private static func validHTTPURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return url
    }

    // MARK: Resume data

    private static func resumeDataDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return base
            .appendingPathComponent("AniXPlayer", isDirectory: true)
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent("ResumeData", isDirectory: true)
    }

    private static func resumeDataURL(for taskID: UUID) -> URL {
        resumeDataDirectory().appendingPathComponent("\(taskID.uuidString).resume")
    }

    private static func writeResumeData(_ data: Data, for taskID: UUID) {
        let directory = resumeDataDirectory()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let url = resumeDataURL(for: taskID)
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    private static func removeResumeData(for taskID: UUID) {
        let url = resumeDataURL(for: taskID)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Transmission engine

final class TransmissionRPCEngine: DownloadEngine {

    private let lock = NSLock()
    private var configuration: TransmissionRPCConfiguration
    private var client: TransmissionRPCClient
    private var taskEngineIDs: [UUID: String] = [:]
    private let downloadSession: URLSession

    init(configuration: TransmissionRPCConfiguration) {
        self.configuration = configuration
        self.client = TransmissionRPCClient(configuration: configuration)

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.downloadSession = URLSession(configuration: config)
    }

    func update(configuration: TransmissionRPCConfiguration) {
        lock.lock()
        self.configuration = configuration
        self.client = TransmissionRPCClient(configuration: configuration)
        lock.unlock()
    }

    func checkAvailability() async throws -> TransmissionSessionInfo {
        try await clientSnapshot().sessionGet()
    }

    // MARK: Protocol

    func add(task: DownloadTask) async throws -> String? {
        let result = try await addTorrent(for: task)
        let engineID = result.engineTaskID
        lock.lock()
        taskEngineIDs[task.id] = engineID
        lock.unlock()
        return engineID
    }

    func start(task: DownloadTask) async throws {
        if let existingID = engineID(for: task) {
            let torrents = try await clientSnapshot().getTorrents(ids: [existingID])
            if !torrents.isEmpty {
                try await clientSnapshot().start(ids: [existingID])
                return
            }
        }
        // daemon 重启或任务丢失：重新添加。
        let result = try await addTorrent(for: task)
        let engineID = result.engineTaskID
        lock.lock()
        taskEngineIDs[task.id] = engineID
        lock.unlock()
        try await clientSnapshot().start(ids: [engineID])
    }

    func pause(task: DownloadTask) async throws {
        guard let engineID = engineID(for: task) else { return }
        try await clientSnapshot().stop(ids: [engineID])
    }

    func stop(task: DownloadTask) async throws {
        guard let engineID = engineID(for: task) else { return }
        try await clientSnapshot().stop(ids: [engineID])
    }

    func remove(task: DownloadTask, deleteFiles: Bool) async throws {
        let engineID = engineID(for: task)
        lock.lock()
        taskEngineIDs.removeValue(forKey: task.id)
        lock.unlock()

        guard let engineID else { return }
        try await clientSnapshot().remove(ids: [engineID], deleteLocalData: deleteFiles)
    }

    func refresh(tasks: [DownloadTask]) async throws -> [DownloadTaskUpdate] {
        let pairs: [(DownloadTask, String)] = tasks.compactMap { task in
            guard let engineID = engineID(for: task) else { return nil }
            return (task, engineID)
        }
        guard !pairs.isEmpty else { return [] }

        let ids = Array(Set(pairs.map { $0.1 }))
        let torrents = try await clientSnapshot().getTorrents(ids: ids)
        var byHash: [String: TransmissionTorrent] = [:]
        var byID: [String: TransmissionTorrent] = [:]
        for torrent in torrents {
            if !torrent.hashKey.isEmpty {
                byHash[torrent.hashKey] = torrent
            }
            byID[String(torrent.id)] = torrent
        }

        return pairs.map { task, engineID in
            let torrent = byHash[engineID.lowercased()] ?? byID[engineID]
            guard let torrent else {
                return DownloadTaskUpdate(
                    taskID: task.id,
                    kind: task.kind,
                    title: nil,
                    status: .failed,
                    progress: task.progress,
                    downloadedBytes: task.downloadedBytes,
                    totalBytes: task.totalBytes,
                    downloadSpeed: 0,
                    uploadSpeed: 0,
                    etaSeconds: nil,
                    errorMessage: NSLocalizedString(
                        "BT 内核中未找到该任务，可能已被移除。请点击开始重试。",
                        comment: ""
                    ),
                    engineTaskID: engineID,
                    filePaths: task.filePaths,
                    isStreaming: false,
                    streamPath: nil
                )
            }
            return makeUpdate(task: task, torrent: torrent)
        }
    }

    // MARK: Internals

    private func clientSnapshot() -> TransmissionRPCClient {
        lock.lock()
        defer { lock.unlock() }
        return client
    }

    private func engineID(for task: DownloadTask) -> String? {
        if let value = task.engineTaskID, !value.isEmpty {
            return value.lowercased()
        }
        lock.lock()
        defer { lock.unlock() }
        return taskEngineIDs[task.id]?.lowercased()
    }

    private func addTorrent(for task: DownloadTask) async throws -> TransmissionTorrentAddResult {
        let config = currentConfiguration()
        let client = clientSnapshot()

        switch task.kind {
        case .magnet:
            return try await client.addTorrent(
                source: task.source,
                savePath: task.savePath,
                sequentialDownload: config.sequentialDownload
            )
        case .torrent:
            let data = try await torrentData(for: task.source)
            return try await client.addTorrent(
                metainfo: data,
                savePath: task.savePath,
                sequentialDownload: config.sequentialDownload
            )
        case .http:
            throw DownloadEngineError.unsupportedSource(task.source)
        }
    }

    private func currentConfiguration() -> TransmissionRPCConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return configuration
    }

    private func torrentData(for source: String) async throws -> Data {
        if source.lowercased().hasPrefix("http://") || source.lowercased().hasPrefix("https://") {
            guard let url = URL(string: source) else {
                throw TransmissionRPCError.torrentFileUnreadable(source)
            }
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await downloadSession.data(from: url)
            } catch {
                throw TransmissionRPCError.torrentFileDownload(error.localizedDescription)
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw TransmissionRPCError.torrentFileDownload("HTTP \(http.statusCode)")
            }
            guard !data.isEmpty, data.count <= 20 * 1024 * 1024 else {
                throw TransmissionRPCError.torrentFileDownload("种子文件为空或过大")
            }
            return data
        }

        let url = URL(fileURLWithPath: source)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            throw TransmissionRPCError.torrentFileUnreadable(source)
        }
        return data
    }

    private func makeUpdate(task: DownloadTask, torrent: TransmissionTorrent) -> DownloadTaskUpdate {
        let finished = torrent.isFinished
        let status: DownloadTaskStatus
        if torrent.error != 0 {
            status = .failed
        } else if finished {
            status = .completed
        } else if task.status == .paused {
            status = .paused
        } else if task.status == .stopped {
            status = .stopped
        } else if torrent.isActivelyDownloading {
            status = .downloading
        } else if torrent.status == 3 || torrent.status == 5 {
            status = .queued
        } else if torrent.status == 0 {
            status = .stopped
        } else {
            status = .downloading
        }

        let downloaded = min(torrent.totalSize, torrent.downloadedBytes)
        let progress = finished ? 1 : torrent.percentDone
        let filePaths = torrent.filePaths
        var streamPath: String?
        if !finished {
            streamPath = DownloadFileRules.preferredFile(
                in: filePaths,
                sizeAtPath: DownloadFileRules.existingFileSize(at:)
            )
            if let size = streamPath.flatMap(DownloadFileRules.existingFileSize(at:)),
               size < DownloadFileRules.minimumStreamingBytes {
                streamPath = nil
            }
        }

        let errorMessage: String?
        if torrent.error != 0 {
            errorMessage = torrent.errorString.isEmpty
                ? String(format: NSLocalizedString("BT 内核报告错误（%d）", comment: ""), torrent.error)
                : torrent.errorString
        } else {
            errorMessage = nil
        }

        let engineID = torrent.hashKey.isEmpty ? task.engineTaskID : torrent.hashKey
        return DownloadTaskUpdate(
            taskID: task.id,
            kind: task.kind,
            title: torrent.name.isEmpty ? nil : torrent.name,
            status: status,
            progress: progress,
            downloadedBytes: downloaded,
            totalBytes: torrent.totalSize,
            downloadSpeed: torrent.rateDownload,
            uploadSpeed: torrent.rateUpload,
            etaSeconds: finished ? nil : torrent.etaSeconds,
            errorMessage: errorMessage,
            engineTaskID: engineID,
            filePaths: filePaths,
            isStreaming: !finished && currentConfiguration().sequentialDownload,
            streamPath: streamPath
        )
    }
}
