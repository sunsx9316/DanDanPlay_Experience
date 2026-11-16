//
//  DownloadManager.swift
//  AniXPlayer
//
//  macOS：下载中心协调器。
//  负责任务持久化、HTTP/BT 引擎选择、轮询、状态合并与重启恢复。
//

import Foundation

enum BTAvailabilityState: Equatable {
    case unknown
    case checking
    case available(String)
    case unavailable(String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .unknown:
            return NSLocalizedString("BT 内核状态未知", comment: "")
        case .checking:
            return NSLocalizedString("正在检测 BT 内核…", comment: "")
        case .available(let version):
            return String(format: NSLocalizedString("BT 内核已连接：%@", comment: ""), version)
        case .unavailable(let message):
            return message
        }
    }
}

final class DownloadManager {

    static let shared = DownloadManager()
    static let didChangeNotification = Notification.Name("AniXPlayer.DownloadManagerDidChange")

    private(set) var tasks: [DownloadTask] = []
    private(set) var storeError: Error?
    private(set) var btState: BTAvailabilityState = .unknown
    private(set) var lastErrorMessage: String?

    let preferences: DownloadPreferences

    private let store: DownloadStore?
    private let httpEngine: HTTPDownloadEngine
    private let btEngine: TransmissionRPCEngine

    private var refreshTimer: Timer?
    private var isBootstrapped = false
    private var isRefreshing = false
    private var startingTaskIDs: Set<UUID> = []

    private init() {
        preferences = DownloadPreferences.shared

        do {
            store = try DownloadStore()
        } catch {
            store = nil
            storeError = error
        }

        httpEngine = HTTPDownloadEngine()
        btEngine = TransmissionRPCEngine(configuration: preferences.rpcConfiguration)
        httpEngine.onUpdate = { [weak self] updates in
            self?.apply(updates: updates)
        }
    }

    // MARK: - Lifecycle

    /// App 启动时调用；窗口打开时也会兜底调用。
    func bootstrap() {
        guard !isBootstrapped else { return }
        isBootstrapped = true

        guard let store else {
            notifyChange()
            return
        }

        do {
            tasks = try store.allTasks()
        } catch {
            storeError = error
            notifyChange()
            return
        }

        recoverInterruptedTasks()
        startRefreshTimer()
        notifyChange()

        checkBTAvailability()
        startQueuedTasksIfNeeded()
    }

    func reloadStore() {
        guard let store else { return }
        do {
            tasks = try store.allTasks()
            notifyChange()
        } catch {
            storeError = error
            notifyChange()
        }
    }

    func reloadSettings() {
        btEngine.update(configuration: preferences.rpcConfiguration)
        checkBTAvailability()
        notifyChange()
    }

    private func recoverInterruptedTasks() {
        guard let store else { return }
        var recovered: [DownloadTask] = []

        for index in tasks.indices {
            guard tasks[index].status == .downloading else { continue }
            var task = tasks[index]
            // 上次退出时仍在下载：标记为等待中，由启动流程自动恢复。
            if task.status.canTransition(to: .queued) {
                try? task.transition(to: .queued)
            } else {
                task.status = .queued
                task.updatedAt = Date()
            }
            task.downloadSpeed = 0
            task.uploadSpeed = 0
            task.etaSeconds = nil
            if task.kind == .http {
                // URLSession 的临时文件不会跨进程保留，重启后从零开始。
                task.progress = 0
                task.downloadedBytes = 0
            }
            tasks[index] = task
            recovered.append(task)
        }

        if !recovered.isEmpty {
            try? store.save(recovered)
        }
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    // MARK: - Add

    func add(
        rawSource: String,
        savePath: String,
        bookmark: Data?,
        completion: @escaping (Result<DownloadTask, Error>) -> Void
    ) {
        lastErrorMessage = nil
        let parsed: DownloadSource
        do {
            parsed = try DownloadSourceParser.parse(rawSource)
        } catch {
            completion(.failure(error))
            return
        }

        let normalizedSavePath = URL(fileURLWithPath: savePath, isDirectory: true)
            .standardizedFileURL
            .path

        func insertTask() {
            let task = DownloadTask(
                kind: parsed.kind,
                source: parsed.source,
                title: parsed.suggestedTitle,
                savePath: normalizedSavePath,
                status: .queued,
                engineTaskID: parsed.infoHash,
                savePathBookmark: bookmark
            )

            if let store {
                do {
                    try store.save(task)
                } catch {
                    completion(.failure(error))
                    return
                }
            }

            tasks.insert(task, at: 0)
            notifyChange()
            completion(.success(task))
            startTask(task)
        }

        if parsed.kind.isBitTorrent {
            guard preferences.enableBT else {
                completion(.failure(DownloadEngineError.btDisabled))
                return
            }
            ensureBTAvailable(forceCheck: true) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    insertTask()
                case .failure(let error):
                    self.setLastError(error.localizedDescription)
                    completion(.failure(error))
                }
            }
        } else {
            insertTask()
        }
    }

    // MARK: - Actions

    func start(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        lastErrorMessage = nil

        for id in ids {
            guard var task = tasks.first(where: { $0.id == id }) else { continue }
            guard task.status != .downloading, task.status != .queued else { continue }

            task.errorMessage = nil
            if task.status.canTransition(to: .queued) {
                try? task.transition(to: .queued)
            } else {
                task.status = .queued
                task.updatedAt = Date()
            }
            updateTask(task, persist: true)
            startTask(task)
        }
        notifyChange()
    }

    func pause(ids: [UUID]) {
        lastErrorMessage = nil
        for id in ids {
            guard var task = tasks.first(where: { $0.id == id }), task.status.canPause else { continue }
            if task.status.canTransition(to: .paused) {
                try? task.transition(to: .paused)
            } else {
                task.status = .paused
            }
            task.downloadSpeed = 0
            task.uploadSpeed = 0
            task.etaSeconds = nil
            updateTask(task, persist: true)

            let engine = engine(for: task)
            Task {
                do { try await engine.pause(task: task) }
                catch { self.onMain { self.setLastError(error.localizedDescription) } }
            }
        }
        notifyChange()
    }

    func stop(ids: [UUID]) {
        lastErrorMessage = nil
        for id in ids {
            guard var task = tasks.first(where: { $0.id == id }), task.status.canStop else { continue }
            if task.status.canTransition(to: .stopped) {
                try? task.transition(to: .stopped)
            } else {
                task.status = .stopped
            }
            task.downloadSpeed = 0
            task.uploadSpeed = 0
            task.etaSeconds = nil
            updateTask(task, persist: true)

            let engine = engine(for: task)
            Task {
                do { try await engine.stop(task: task) }
                catch { self.onMain { self.setLastError(error.localizedDescription) } }
            }
        }
        notifyChange()
    }

    func remove(ids: [UUID], deleteFiles: Bool) {
        guard !ids.isEmpty else { return }
        lastErrorMessage = nil
        let removing = tasks.filter { ids.contains($0.id) }
        guard !removing.isEmpty else { return }

        for task in removing {
            let engine = engine(for: task)
            Task {
                do { try await engine.remove(task: task, deleteFiles: deleteFiles) }
                catch { self.onMain { self.setLastError(error.localizedDescription) } }
            }
            if deleteFiles {
                deleteLocalFiles(for: task)
            }
            startingTaskIDs.remove(task.id)
        }

        tasks.removeAll { ids.contains($0.id) }
        try? store?.delete(ids: removing.map { $0.id })
        notifyChange()
        startQueuedTasksIfNeeded()
    }

    // MARK: - Playback

    func completedPlaybackURL(for task: DownloadTask) -> URL? {
        guard task.status == .completed,
              let path = DownloadFileRules.playablePath(for: task) else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    /// BT 未完成任务：文件已存在且 >20MB 时允许 best-effort 播放。
    func streamingPlaybackURL(for task: DownloadTask) -> URL? {
        guard task.isBitTorrent,
              task.status != .completed,
              let path = DownloadFileRules.playablePath(for: task) else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    // MARK: - BT availability

    func checkBTAvailability(completion: ((Result<String, Error>) -> Void)? = nil) {
        guard preferences.enableBT else {
            btState = .unavailable(DownloadEngineError.btDisabled.localizedDescription)
            notifyChange()
            completion?(.failure(DownloadEngineError.btDisabled))
            return
        }

        btState = .checking
        notifyChange()
        btEngine.update(configuration: preferences.rpcConfiguration)

        Task { [weak self] in
            guard let self else { return }
            do {
                let info = try await self.btEngine.checkAvailability()
                self.onMain {
                    self.btState = .available(info.version)
                    self.lastErrorMessage = nil
                    self.notifyChange()
                    completion?(.success(info.version))
                    self.startQueuedTasksIfNeeded()
                }
            } catch {
                let message = error.localizedDescription
                self.onMain {
                    self.btState = .unavailable(message)
                    self.notifyChange()
                    completion?(.failure(error))
                }
            }
        }
    }

    private func ensureBTAvailable(forceCheck: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
        guard preferences.enableBT else {
            completion(.failure(DownloadEngineError.btDisabled))
            return
        }
        if !forceCheck, case .available(let version) = btState {
            completion(.success(version))
            return
        }
        checkBTAvailability(completion: completion)
    }

    // MARK: - Starting tasks

    private func startQueuedTasksIfNeeded() {
        guard isBootstrapped else { return }

        let httpActive = tasks.filter { $0.kind == .http && $0.status == .downloading }.count
        var httpSlots = max(0, preferences.maxConcurrentDownloads - httpActive)
        for task in tasks where task.kind == .http && task.status == .queued && httpSlots > 0 {
            guard !startingTaskIDs.contains(task.id) else { continue }
            httpSlots -= 1
            startTask(task)
        }

        guard btState.isAvailable, preferences.enableBT else { return }
        for task in tasks where task.kind.isBitTorrent && task.status == .queued {
            guard !startingTaskIDs.contains(task.id) else { continue }
            startTask(task)
        }
    }

    private func startTask(_ task: DownloadTask) {
        guard isBootstrapped else { return }
        guard !startingTaskIDs.contains(task.id) else { return }
        guard let current = tasks.first(where: { $0.id == task.id }) else { return }

        startingTaskIDs.insert(task.id)

        if current.kind == .http {
            startHTTPTask(current)
        } else {
            startBitTorrentTask(current)
        }
    }

    private func startHTTPTask(_ task: DownloadTask) {
        let active = tasks.filter { $0.kind == .http && $0.status == .downloading }.count
        guard active < preferences.maxConcurrentDownloads else {
            startingTaskIDs.remove(task.id)
            var queued = task
            queued.status = .queued
            queued.updatedAt = Date()
            updateTask(queued, persist: true)
            notifyChange()
            return
        }

        var running = task
        running.status = .downloading
        running.errorMessage = nil
        running.updatedAt = Date()
        updateTask(running, persist: true)
        notifyChange()

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.httpEngine.add(task: running)
                try await self.httpEngine.start(task: running)
                self.onMain { self.startingTaskIDs.remove(running.id) }
            } catch {
                self.onMain {
                    self.startingTaskIDs.remove(running.id)
                    self.markFailed(taskID: running.id, error: error)
                }
            }
        }
    }

    private func startBitTorrentTask(_ task: DownloadTask) {
        guard preferences.enableBT else {
            startingTaskIDs.remove(task.id)
            markFailed(taskID: task.id, error: DownloadEngineError.btDisabled)
            return
        }

        var queued = task
        queued.status = .queued
        queued.errorMessage = nil
        queued.updatedAt = Date()
        updateTask(queued, persist: true)
        notifyChange()

        Task { [weak self] in
            guard let self else { return }
            do {
                if !self.btState.isAvailable {
                    let info = try await self.btEngine.checkAvailability()
                    self.onMain { self.btState = .available(info.version) }
                }

                var working = queued
                let engineID = try await self.btEngine.add(task: working)
                if let engineID, !engineID.isEmpty {
                    working.engineTaskID = engineID
                }
                try await self.btEngine.start(task: working)

                self.onMain {
                    self.startingTaskIDs.remove(working.id)
                    var updated = working
                    updated.status = .downloading
                    updated.updatedAt = Date()
                    self.updateTask(updated, persist: true)
                    self.notifyChange()
                }
            } catch {
                self.onMain {
                    self.startingTaskIDs.remove(queued.id)
                    if let rpcError = error as? TransmissionRPCError {
                        switch rpcError {
                        case .unavailable, .unauthorized:
                            self.btState = .unavailable(error.localizedDescription)
                        default:
                            break
                        }
                    }
                    self.markFailed(taskID: queued.id, error: error)
                }
            }
        }
    }

    // MARK: - Polling

    func refreshNow() {
        poll()
    }

    private func poll() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let snapshot = tasks
        let btCandidates = snapshot.filter {
            $0.kind.isBitTorrent
                && $0.status == .downloading
                && !($0.engineTaskID ?? "").isEmpty
        }

        Task { [weak self] in
            guard let self else { return }
            var updates: [DownloadTaskUpdate] = []
            var btError: Error?

            if let httpUpdates = try? await self.httpEngine.refresh(tasks: snapshot) {
                updates.append(contentsOf: httpUpdates)
            }
            if !btCandidates.isEmpty, self.preferences.enableBT {
                do {
                    updates.append(contentsOf: try await self.btEngine.refresh(tasks: btCandidates))
                } catch {
                    btError = error
                }
            }

            self.onMain {
                self.isRefreshing = false
                if !updates.isEmpty {
                    self.apply(updates: updates)
                }
                if let btError {
                    self.handleBTPollError(btError, candidates: btCandidates)
                }
                self.startQueuedTasksIfNeeded()
            }
        }
    }

    private func handleBTPollError(_ error: Error, candidates: [DownloadTask]) {
        let message = error.localizedDescription
        btState = .unavailable(message)
        for task in candidates where task.status == .downloading {
            markFailed(taskID: task.id, error: error)
        }
        notifyChange()
    }

    // MARK: - Applying engine updates

    private func apply(updates: [DownloadTaskUpdate]) {
        guard !updates.isEmpty else { return }
        var changed = false

        for update in updates {
            guard let index = tasks.firstIndex(where: { $0.id == update.taskID }) else { continue }
            let old = tasks[index]
            var task = old

            if update.status != task.status {
                if task.status.canTransition(to: update.status) {
                    try? task.transition(to: update.status)
                } else if update.status == .downloading {
                    // 引擎正在跑但本地状态落后（例如刚恢复），以引擎为准。
                    task.status = .downloading
                }
            } else if update.status == .completed {
                task.progress = 1
            }

            if let title = update.title, !title.isEmpty {
                task.title = title
            }
            task.progress = min(max(update.progress, 0), 1)
            task.downloadedBytes = max(0, update.downloadedBytes)
            task.totalBytes = max(0, update.totalBytes)
            task.downloadSpeed = max(0, update.downloadSpeed)
            task.uploadSpeed = max(0, update.uploadSpeed)
            task.etaSeconds = update.status == .completed ? nil : update.etaSeconds
            task.errorMessage = update.errorMessage

            if !update.filePaths.isEmpty || update.status == .completed {
                task.filePaths = update.filePaths
            }
            if let engineTaskID = update.engineTaskID, !engineTaskID.isEmpty {
                task.engineTaskID = engineTaskID
            }
            task.isStreaming = update.isStreaming
            task.streamPath = update.streamPath
            task.updatedAt = Date()

            if task != old {
                tasks[index] = task
                try? store?.save(task)
                changed = true
            }
        }

        if changed {
            notifyChange()
        }
    }

    private func updateTask(_ task: DownloadTask, persist: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        if persist {
            try? store?.save(task)
        }
    }

    private func markFailed(taskID: UUID, error: Error) {
        guard var task = tasks.first(where: { $0.id == taskID }) else { return }
        if task.status.canTransition(to: .failed) {
            try? task.transition(to: .failed)
        } else {
            task.status = .failed
            task.updatedAt = Date()
        }
        task.downloadSpeed = 0
        task.uploadSpeed = 0
        task.etaSeconds = nil
        task.errorMessage = error.localizedDescription
        updateTask(task, persist: true)
        setLastError(error.localizedDescription)
        notifyChange()
    }

    private func engine(for task: DownloadTask) -> DownloadEngine {
        task.kind == .http ? httpEngine : btEngine
    }

    // MARK: - Files

    private func deleteLocalFiles(for task: DownloadTask) {
        let access = DownloadFileAccess.resolveDirectory(
            path: task.savePath,
            bookmark: task.savePathBookmark
        )
        defer { access.securityScopedURL?.stopAccessingSecurityScopedResource() }

        for path in Set(task.filePaths) {
            if FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }

    // MARK: - Summary

    var totalDownloadSpeed: Int64 {
        tasks.reduce(0) { $0 + max(0, $1.downloadSpeed) }
    }

    var totalUploadSpeed: Int64 {
        tasks.reduce(0) { $0 + max(0, $1.uploadSpeed) }
    }

    var activeTaskCount: Int {
        tasks.filter { $0.status == .downloading }.count
    }

    func clearLastError() {
        lastErrorMessage = nil
        notifyChange()
    }

    private func setLastError(_ message: String) {
        lastErrorMessage = message
    }

    // MARK: - Notification

    private func notifyChange() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        } else {
            onMain { self.notifyChange() }
        }
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
