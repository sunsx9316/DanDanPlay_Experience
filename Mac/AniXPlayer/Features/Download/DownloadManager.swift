//
//  DownloadManager.swift
//  AniXPlayer
//
//  macOS：下载中心协调器。
//  负责任务持久化、HTTP/BT 引擎选择、轮询、状态合并、队列与重启恢复。
//

import AppKit
import Foundation

enum BTAvailabilityState: Equatable {
    case unknown
    case checking
    case available(String)
    case unavailable(String)
    case error(String)

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
        case .unavailable(let message), .error(let message):
            return message
        }
    }
}

struct DownloadAddResult {
    let task: DownloadTask
    let isDuplicate: Bool
}

final class DownloadManager {

    static let shared = DownloadManager()
    static let didChangeNotification = Notification.Name("AniXPlayer.DownloadManagerDidChange")

    private(set) var tasks: [DownloadTask] = []
    private(set) var storeError: Error?
    private(set) var btState: BTAvailabilityState = .unknown
    private(set) var lastErrorMessage: String?
    private(set) var lastNoticeMessage: String?

    let preferences: DownloadPreferences

    private let store: DownloadStore?
    private let httpEngine: HTTPDownloadEngine
    private let btEngine: TransmissionRPCEngine
    private let notifier: DownloadNotifier

    private var refreshTimer: Timer?
    private var isBootstrapped = false
    private var isRefreshing = false
    private var startingTaskIDs: Set<UUID> = []
    /// 每次启动生成一个 token；暂停/停止/删除后，迟到的引擎回调据此判断是否还应生效。
    private var startTokens: [UUID: UUID] = [:]
    private var lastKnownEnableBT: Bool
    private var lastNotifiedStatus: [UUID: DownloadTaskStatus] = [:]
    /// 暂停/停止操作的 token：若用户立刻继续，旧的引擎调用会跳过。
    private var controlTokens: [UUID: UUID] = [:]
    /// 当前进程已交给 Transmission、正在等待/下载的 BT 任务，用于本地并发门控并避免重复 torrent-start。
    private var btWaitingTaskIDs: Set<UUID> = []
    /// BT 单文件进度，来自轮询；仅内存保存。
    private var taskFiles: [UUID: [DownloadFileProgress]] = [:]

    private init() {
        preferences = DownloadPreferences.shared
        notifier = DownloadNotifier.shared
        lastKnownEnableBT = preferences.enableBT

        do {
            store = try DownloadStore()
        } catch {
            store = nil
            storeError = error
        }

        httpEngine = HTTPDownloadEngine()
        btEngine = TransmissionRPCEngine(configuration: preferences.rpcConfiguration)
        httpEngine.onUpdate = { [weak self] updates in
            guard let self else { return }
            self.apply(updates: updates)
            self.startQueuedTasksIfNeeded()
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
            tasks = try store.allTasks().map(Self.normalizedTask)
            storeError = nil
            pruneTransientState()
        } catch {
            storeError = error
            notifyChange()
            return
        }

        recoverInterruptedTasks()
        startRefreshTimer()
        updateDockBadge()
        notifyChange()

        if !preferences.enableBT {
            pauseBTTasksForDisabledIntegration()
            btState = .unavailable(DownloadEngineError.btDisabled.localizedDescription)
            notifyChange()
        } else {
            checkBTAvailability()
        }
        startQueuedTasksIfNeeded()
    }

    func reloadStore() {
        guard let store else { return }
        do {
            tasks = try store.allTasks().map(Self.normalizedTask)
            storeError = nil
            pruneTransientState()
            notifyChange()
            startQueuedTasksIfNeeded()
        } catch {
            storeError = error
            notifyChange()
        }
    }

    private func pruneTransientState() {
        let ids = Set(tasks.map { $0.id })
        btWaitingTaskIDs.formIntersection(ids)
        startingTaskIDs.formIntersection(ids)
        controlTokens = controlTokens.filter { ids.contains($0.key) }
        startTokens = startTokens.filter { ids.contains($0.key) }
        taskFiles = taskFiles.filter { ids.contains($0.key) }
        lastNotifiedStatus = lastNotifiedStatus.filter { ids.contains($0.key) }
    }

    private static func normalizedTask(_ task: DownloadTask) -> DownloadTask {
        guard let normalized = DownloadSourceParser.normalizedInfoHash(task.engineTaskID),
              normalized != task.engineTaskID else {
            return task
        }
        var updated = task
        updated.engineTaskID = normalized
        return updated
    }

    func reloadSettings() {
        let enabled = preferences.enableBT
        let wasEnabled = lastKnownEnableBT
        lastKnownEnableBT = enabled
        btEngine.update(configuration: preferences.rpcConfiguration)

        if wasEnabled && !enabled {
            pauseBTTasksForDisabledIntegration()
        }

        guard enabled else {
            btState = .unavailable(DownloadEngineError.btDisabled.localizedDescription)
            notifyChange()
            startQueuedTasksIfNeeded()
            return
        }

        if case .unavailable(let message) = btState,
           message == DownloadEngineError.btDisabled.localizedDescription {
            btState = .unknown
        }
        checkBTAvailability()
        notifyChange()
    }

    private func recoverInterruptedTasks() {
        guard let store else { return }
        var recovered: [DownloadTask] = []

        for index in tasks.indices {
            guard tasks[index].status == .downloading else { continue }
            var task = tasks[index]
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
        completion: @escaping (Result<DownloadAddResult, Error>) -> Void
    ) {
        lastErrorMessage = nil
        lastNoticeMessage = nil

        guard store != nil, storeError == nil else {
            let error = DownloadEngineError.storeUnavailable(
                storeError?.localizedDescription
                    ?? NSLocalizedString("下载数据库不可用。", comment: "")
            )
            setLastError(error.localizedDescription)
            completion(.failure(error))
            return
        }

        let parsed: DownloadSource
        do {
            parsed = try DownloadSourceParser.parse(rawSource)
        } catch {
            completion(.failure(error))
            return
        }

        var safeParsed = parsed
        if parsed.kind == .torrent,
           !parsed.source.lowercased().hasPrefix("http://"),
           !parsed.source.lowercased().hasPrefix("https://"),
           !DownloadTorrentImporter.isImportedTorrent(parsed.source) {
            do {
                let importedPath = try DownloadTorrentImporter.importTorrent(
                    at: URL(fileURLWithPath: parsed.source)
                )
                safeParsed = try DownloadSourceParser.parse(importedPath)
            } catch {
                completion(.failure(error))
                return
            }
        }

        let key = DownloadSourceParser.deduplicationKey(for: safeParsed)
        if let existing = tasks.first(where: {
            DownloadSourceParser.deduplicationKey(for: $0) == key
        }) {
            setLastNotice(String(
                format: NSLocalizedString("「%@」已经在下载列表中，已定位到现有任务。", comment: ""),
                existing.displayTitle
            ))
            notifyChange()
            completion(.success(DownloadAddResult(task: existing, isDuplicate: true)))
            return
        }

        let normalizedSavePath = URL(fileURLWithPath: savePath, isDirectory: true)
            .standardizedFileURL
            .path

        func insertTask() {
            let task = DownloadTask(
                kind: safeParsed.kind,
                source: safeParsed.source,
                title: safeParsed.suggestedTitle,
                savePath: normalizedSavePath,
                status: .queued,
                engineTaskID: safeParsed.infoHash,
                savePathBookmark: bookmark
            )

            if let store {
                do {
                    try store.save(task)
                } catch {
                    setLastError(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
            }

            tasks.insert(task, at: 0)
            notifier.requestAuthorizationIfNeeded(preferences: preferences)
            notifyChange()
            completion(.success(DownloadAddResult(task: task, isDuplicate: false)))
            startTask(task)
        }

        if safeParsed.kind.isBitTorrent {
            guard preferences.enableBT else {
                let error = DownloadEngineError.btDisabled
                setLastError(error.localizedDescription)
                completion(.failure(error))
                return
            }
            ensureBTAvailable(forceCheck: true) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    insertTask()
                case .failure(let error):
                    let setupError = DownloadEngineError.btOnboardingRequired(
                        error.localizedDescription
                    )
                    self.setLastError(setupError.localizedDescription)
                    completion(.failure(setupError))
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
        lastNoticeMessage = nil

        for id in ids {
            guard var task = tasks.first(where: { $0.id == id }) else { continue }
            guard task.status.canStart else { continue }

            lastNotifiedStatus.removeValue(forKey: id)
            btWaitingTaskIDs.remove(id)
            controlTokens.removeValue(forKey: id)
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
        guard !ids.isEmpty else { return }
        lastErrorMessage = nil
        lastNoticeMessage = nil

        for id in ids {
            guard var task = tasks.first(where: { $0.id == id }), task.status.canPause else { continue }
            btWaitingTaskIDs.remove(id)
            if task.status.canTransition(to: .paused) {
                try? task.transition(to: .paused)
            } else {
                task.status = .paused
                task.updatedAt = Date()
            }
            task.downloadSpeed = 0
            task.uploadSpeed = 0
            task.etaSeconds = nil
            updateTask(task, persist: true)
            let token = UUID()
            controlTokens[id] = token

            let engine = engine(for: task)
            Task { [weak self] in
                guard let self else { return }
                guard self.onMainSync({
                    self.controlTokens[id] == token
                        && self.tasks.first(where: { $0.id == id })?.status == .paused
                }) else { return }
                do {
                    try await engine.pause(task: task)
                } catch {
                    self.onMain {
                        guard self.controlTokens[id] == token else { return }
                        self.setLastError(error.localizedDescription)
                        self.notifyChange()
                    }
                }
            }
        }
        notifyChange()
        startQueuedTasksIfNeeded()
    }

    func stop(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        lastErrorMessage = nil
        lastNoticeMessage = nil

        for id in ids {
            guard var task = tasks.first(where: { $0.id == id }), task.status.canStop else { continue }
            btWaitingTaskIDs.remove(id)
            if task.status.canTransition(to: .stopped) {
                try? task.transition(to: .stopped)
            } else {
                task.status = .stopped
                task.updatedAt = Date()
            }
            task.downloadSpeed = 0
            task.uploadSpeed = 0
            task.etaSeconds = nil
            updateTask(task, persist: true)
            let token = UUID()
            controlTokens[id] = token

            let engine = engine(for: task)
            Task { [weak self] in
                guard let self else { return }
                guard self.onMainSync({
                    self.controlTokens[id] == token
                        && self.tasks.first(where: { $0.id == id })?.status == .stopped
                }) else { return }
                do {
                    try await engine.stop(task: task)
                } catch {
                    self.onMain {
                        guard self.controlTokens[id] == token else { return }
                        self.setLastError(error.localizedDescription)
                        self.notifyChange()
                    }
                }
            }
        }
        notifyChange()
        startQueuedTasksIfNeeded()
    }

    func pauseAll() {
        pause(ids: tasks.filter { $0.status.canPause }.map { $0.id })
    }

    func resumeAll() {
        start(ids: tasks.filter { $0.status.canStart }.map { $0.id })
    }

    func remove(ids: [UUID], deleteFiles: Bool) {
        guard !ids.isEmpty else { return }
        lastErrorMessage = nil
        lastNoticeMessage = nil
        let removing = tasks.filter { ids.contains($0.id) }
        guard !removing.isEmpty else { return }

        for task in removing {
            let engine = engine(for: task)
            Task { [weak self] in
                do {
                    try await engine.remove(task: task, deleteFiles: deleteFiles)
                } catch {
                    self?.onMain { self?.setLastError(error.localizedDescription); self?.notifyChange() }
                }
            }
            if deleteFiles {
                deleteLocalFiles(for: task)
            }
            if task.kind == .torrent {
                DownloadTorrentImporter.removeImportedTorrent(task.source)
            }
            if !startingTaskIDs.contains(task.id) {
                startTokens.removeValue(forKey: task.id)
            }
            btWaitingTaskIDs.remove(task.id)
            controlTokens.removeValue(forKey: task.id)
            taskFiles.removeValue(forKey: task.id)
            lastNotifiedStatus.removeValue(forKey: task.id)
        }

        tasks.removeAll { ids.contains($0.id) }
        try? store?.delete(ids: removing.map { $0.id })
        notifyChange()
        startQueuedTasksIfNeeded()
    }

    // MARK: - Playback

    /// 完成任务的完整播放列表（自然顺序，从第一集开始）。
    func completedPlaybackURLs(for task: DownloadTask) -> [URL] {
        DownloadFileRules.playablePaths(for: task)
            .map { URL(fileURLWithPath: $0) }
    }

    func completedPlaybackURL(for task: DownloadTask) -> URL? {
        completedPlaybackURLs(for: task).first
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
                    guard self.preferences.enableBT else {
                        self.btState = .unavailable(DownloadEngineError.btDisabled.localizedDescription)
                        self.notifyChange()
                        completion?(.failure(DownloadEngineError.btDisabled))
                        return
                    }
                    self.btState = .available(info.version)
                    self.lastErrorMessage = nil
                    if self.preferences.btOnboardingDismissed {
                        self.preferences.setBTOnboardingDismissed(false)
                    }
                    self.notifyChange()
                    completion?(.success(info.version))
                    self.startQueuedTasksIfNeeded()
                }
            } catch {
                let message = error.localizedDescription
                self.onMain {
                    guard self.preferences.enableBT else {
                        self.btState = .unavailable(DownloadEngineError.btDisabled.localizedDescription)
                        self.notifyChange()
                        completion?(.failure(DownloadEngineError.btDisabled))
                        return
                    }
                    if let rpcError = error as? TransmissionRPCError,
                       case .unauthorized = rpcError {
                        self.btState = .error(message)
                    } else {
                        self.btState = .unavailable(message)
                    }
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

    private func pauseBTTasksForDisabledIntegration() {
        var pausedAny = false
        for id in tasks.map({ $0.id }) {
            guard var task = tasks.first(where: { $0.id == id }),
                  task.kind.isBitTorrent,
                  task.status == .queued || task.status == .downloading else {
                continue
            }
            btWaitingTaskIDs.remove(id)
            if task.status.canTransition(to: .paused) {
                try? task.transition(to: .paused)
            } else {
                task.status = .paused
                task.updatedAt = Date()
            }
            task.downloadSpeed = 0
            task.uploadSpeed = 0
            task.etaSeconds = nil
            updateTask(task, persist: true)
            pausedAny = true

            let engine = btEngine
            Task {
                try? await engine.pause(task: task)
            }
        }
        if pausedAny {
            setLastNotice(NSLocalizedString("BT 集成已关闭，进行中的 BT 任务已暂停。", comment: ""))
        }
    }

    // MARK: - Queue

    private func occupiedSlotIDs(excluding excludedID: UUID? = nil) -> Set<UUID> {
        var ids = Set<UUID>()
        for task in tasks where task.status == .downloading {
            ids.insert(task.id)
        }
        ids.formUnion(btWaitingTaskIDs)
        ids.formUnion(startingTaskIDs)
        if let excludedID {
            ids.remove(excludedID)
        }
        return ids
    }

    private func hasFreeSlot(excluding taskID: UUID? = nil) -> Bool {
        occupiedSlotIDs(excluding: taskID).count < preferences.maxConcurrentDownloads
    }

    private func startQueuedTasksIfNeeded() {
        guard isBootstrapped else { return }

        var slots = max(0, preferences.maxConcurrentDownloads - occupiedSlotIDs().count)
        guard slots > 0 else { return }

        for task in tasks where task.status == .queued {
            guard slots > 0 else { break }
            guard !startingTaskIDs.contains(task.id) else { continue }

            if task.kind.isBitTorrent {
                guard preferences.enableBT, btState.isAvailable else { continue }
                // 已交给 daemon、正在等待/校验的种子不重复 torrent-start。
                if btWaitingTaskIDs.contains(task.id) { continue }
            }

            startTask(task)
            slots -= 1
        }
    }

    private func startTask(_ task: DownloadTask) {
        guard isBootstrapped else { return }
        guard !startingTaskIDs.contains(task.id) else { return }
        guard let current = tasks.first(where: { $0.id == task.id }),
              current.status == .queued else {
            return
        }
        if current.kind.isBitTorrent, btWaitingTaskIDs.contains(current.id) {
            return
        }
        guard hasFreeSlot(excluding: current.id) else { return }

        let token = UUID()
        startTokens[current.id] = token
        startingTaskIDs.insert(current.id)

        if current.kind == .http {
            startHTTPTask(current, token: token)
        } else {
            startBitTorrentTask(current, token: token)
        }
    }

    private func startHTTPTask(_ task: DownloadTask, token: UUID) {
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
                guard self.isStartCurrent(taskID: running.id, token: token, allowing: [.downloading]) else {
                    self.onMain { self.finishLateStart(running, token: token) }
                    return
                }
                try await self.httpEngine.start(task: running)
                self.onMain {
                    guard self.startTokens[running.id] == token else { return }
                    guard let current = self.tasks.first(where: { $0.id == running.id }),
                          current.status == .downloading else {
                        self.finishLateStart(running, token: token)
                        return
                    }
                    self.finishStart(taskID: running.id, token: token)
                    self.startQueuedTasksIfNeeded()
                }
            } catch {
                self.onMain {
                    guard self.startTokens[running.id] == token else { return }
                    guard let current = self.tasks.first(where: { $0.id == running.id }),
                          current.status == .downloading || current.status == .queued else {
                        self.finishLateStart(running, token: token)
                        return
                    }
                    self.finishStart(taskID: running.id, token: token)
                    self.markFailed(taskID: running.id, error: error)
                }
            }
        }
    }

    private func startBitTorrentTask(_ task: DownloadTask, token: UUID) {
        guard preferences.enableBT else {
            finishStart(taskID: task.id, token: token)
            markFailed(taskID: task.id, error: DownloadEngineError.btDisabled)
            return
        }

        var queued = task
        if let normalized = DownloadSourceParser.normalizedInfoHash(queued.engineTaskID) {
            queued.engineTaskID = normalized
        }
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
                if DownloadSourceParser.normalizedInfoHash(working.engineTaskID) == nil {
                    if let engineID = try await self.btEngine.add(task: working),
                       !engineID.isEmpty {
                        working.engineTaskID = engineID
                    }
                }

                guard self.isStartCurrent(taskID: working.id, token: token, allowing: [.queued, .downloading]) else {
                    self.onMain { self.finishLateStart(working, token: token) }
                    return
                }

                try await self.btEngine.start(task: working)
                self.onMain {
                    guard self.startTokens[working.id] == token else { return }
                    guard let current = self.tasks.first(where: { $0.id == working.id }),
                          current.status == .queued || current.status == .downloading else {
                        self.finishLateStart(working, token: token)
                        return
                    }
                    var updated = current
                    updated.engineTaskID = working.engineTaskID ?? current.engineTaskID
                    self.updateTask(updated, persist: true)
                    self.btWaitingTaskIDs.insert(working.id)
                    self.finishStart(taskID: working.id, token: token)
                    self.notifyChange()
                    self.startQueuedTasksIfNeeded()
                }
            } catch {
                self.onMain {
                    guard self.startTokens[queued.id] == token else { return }
                    guard let current = self.tasks.first(where: { $0.id == queued.id }),
                          current.status == .queued || current.status == .downloading else {
                        self.finishLateStart(queued, token: token)
                        return
                    }
                    if let rpcError = error as? TransmissionRPCError {
                        switch rpcError {
                        case .unavailable:
                            self.btState = .unavailable(error.localizedDescription)
                        case .unauthorized:
                            self.btState = .error(error.localizedDescription)
                        default:
                            break
                        }
                    }
                    self.finishStart(taskID: queued.id, token: token)
                    Task { try? await self.btEngine.stop(task: current) }
                    self.markFailed(taskID: queued.id, error: error)
                }
            }
        }
    }

    private func isStartCurrent(
        taskID: UUID,
        token: UUID,
        allowing statuses: Set<DownloadTaskStatus>
    ) -> Bool {
        onMainSync {
            guard startTokens[taskID] == token,
                  let task = tasks.first(where: { $0.id == taskID }) else {
                return false
            }
            return statuses.contains(task.status)
        }
    }

    private func finishStart(taskID: UUID, token: UUID) {
        guard startTokens[taskID] == token else { return }
        startTokens.removeValue(forKey: taskID)
        startingTaskIDs.remove(taskID)
    }

    /// 用户在启动/添加过程中暂停、停止或删除了任务：停止刚刚被引擎接管的下载。
    private func finishLateStart(_ task: DownloadTask, token: UUID) {
        guard startTokens[task.id] == token else { return }
        startTokens.removeValue(forKey: task.id)
        startingTaskIDs.remove(task.id)

        guard let current = tasks.first(where: { $0.id == task.id }) else {
            if hasAnotherTaskForSameBTID(task) {
                return
            }
            let engine = engine(for: task)
            Task {
                try? await engine.remove(task: task, deleteFiles: false)
            }
            return
        }

        let engine = engine(for: current)
        switch current.status {
        case .paused:
            Task { try? await engine.pause(task: current) }
        case .stopped:
            Task { try? await engine.stop(task: current) }
        case .queued:
            startTask(current)
        default:
            break
        }
    }

    private func hasAnotherTaskForSameBTID(_ task: DownloadTask) -> Bool {
        guard task.kind.isBitTorrent else { return false }
        guard let hash = DownloadSourceParser.normalizedInfoHash(task.engineTaskID)
            ?? DownloadSourceParser.normalizedInfoHash(
                DownloadSourceParser.magnetInfoHash(in: task.source)
            ) else {
            return false
        }
        return tasks.contains { other in
            guard other.id != task.id, other.kind.isBitTorrent else { return false }
            let otherHash = DownloadSourceParser.normalizedInfoHash(other.engineTaskID)
                ?? DownloadSourceParser.normalizedInfoHash(
                    DownloadSourceParser.magnetInfoHash(in: other.source)
                )
            return otherHash == hash
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
        let btWasAvailable = btState.isAvailable
        let btCandidates = snapshot.filter { task in
            guard task.kind.isBitTorrent,
                  !(task.engineTaskID ?? "").isEmpty,
                  !startingTaskIDs.contains(task.id) else {
                return false
            }
            if task.status == .downloading {
                return true
            }
            if task.status == .queued {
                // 只有本进程已交给 daemon 的任务才轮询等待状态，避免把尚未启动的任务误判为丢失。
                return btWaitingTaskIDs.contains(task.id)
            }
            // 暂停/停止的任务只在还没有文件列表时查询一次，供详情页选择文件。
            if task.status == .paused || task.status == .stopped {
                return taskFiles[task.id] == nil
            }
            return false
        }

        Task { [weak self] in
            guard let self else { return }
            var updates: [DownloadTaskUpdate] = []
            var btError: Error?
            var btRefreshSucceeded = false

            if let httpUpdates = try? await self.httpEngine.refresh(tasks: snapshot) {
                updates.append(contentsOf: httpUpdates)
            }
            let shouldPollBT = self.preferences.enableBT && (
                btWasAvailable
                    || btCandidates.contains {
                        $0.status == .downloading || $0.status == .queued
                    }
            )
            if !btCandidates.isEmpty, shouldPollBT {
                do {
                    updates.append(contentsOf: try await self.btEngine.refresh(tasks: btCandidates))
                    btRefreshSucceeded = true
                } catch {
                    btError = error
                }
            }

            self.onMain {
                self.isRefreshing = false
                if !updates.isEmpty {
                    self.apply(updates: updates)
                }
                if self.preferences.enableBT {
                    if let btError {
                        self.handleBTPollError(btError)
                    } else if btRefreshSucceeded, !self.btState.isAvailable {
                        self.checkBTAvailability()
                    }
                }
                self.startQueuedTasksIfNeeded()
            }
        }
    }

    private func handleBTPollError(_ error: Error) {
        let message = error.localizedDescription
        let newState: BTAvailabilityState
        if let rpcError = error as? TransmissionRPCError,
           case .unauthorized = rpcError {
            newState = .error(message)
        } else {
            newState = .unavailable(message)
        }
        guard btState != newState else { return }
        btState = newState
        // 只更新内核状态，不把仍在 daemon 里运行的任务标记为失败；
        // 连接恢复后轮询会继续更新，避免瞬时网络错误造成误报。
        notifyChange()
    }

    // MARK: - Applying engine updates

    private func apply(updates: [DownloadTaskUpdate]) {
        guard !updates.isEmpty else { return }
        var changed = false

        for update in updates {
            guard let index = tasks.firstIndex(where: { $0.id == update.taskID }) else { continue }
            let old = tasks[index]
            if old.kind.isBitTorrent, !preferences.enableBT {
                // BT 已关闭时，忽略仍在途的 daemon 回调，避免把刚暂停的任务重新激活。
                continue
            }
            var task = old
            let oldStatus = old.status

            if old.status == .completed {
                // 已完成任务不允许被引擎回调降级/重启；只刷新文件元数据。
                task.status = .completed
                task.progress = 1
                task.downloadSpeed = 0
                task.uploadSpeed = 0
                task.etaSeconds = nil
            } else if update.status != task.status {
                if task.status.canTransition(to: update.status) {
                    try? task.transition(to: update.status)
                }
            }

            if let title = update.title?.trimmingCharacters(in: .whitespacesAndNewlines),
               !title.isEmpty {
                task.title = title
            }
            task.progress = min(max(update.progress, 0), 1)
            task.downloadedBytes = max(0, update.downloadedBytes)
            task.totalBytes = max(0, update.totalBytes)
            task.downloadSpeed = max(0, update.downloadSpeed)
            task.uploadSpeed = max(0, update.uploadSpeed)
            task.etaSeconds = task.status == .completed ? nil : update.etaSeconds
            task.errorMessage = task.status == .completed ? nil : update.errorMessage

            if !update.filePaths.isEmpty {
                task.filePaths = update.filePaths
            }
            if let engineTaskID = update.engineTaskID, !engineTaskID.isEmpty {
                task.engineTaskID = engineTaskID
            }
            task.isStreaming = update.isStreaming
            task.streamPath = update.streamPath

            if task.status == .completed {
                task.progress = 1
                task.downloadSpeed = 0
                task.uploadSpeed = 0
                task.etaSeconds = nil
            }

            let materialChange = task != old
            if materialChange {
                task.updatedAt = Date()
                tasks[index] = task
                _ = try? store?.save(task)
                changed = true
                if oldStatus != task.status {
                    if !task.status.isActive {
                        btWaitingTaskIDs.remove(task.id)
                    }
                    noteNotificationTransition(task: task, from: oldStatus)
                }
            } else if task.status == .completed && old.progress != 1 {
                task.updatedAt = Date()
                tasks[index] = task
                _ = try? store?.save(task)
                changed = true
            }

            if !update.files.isEmpty {
                let previous = taskFiles[update.taskID] ?? []
                if previous != update.files {
                    taskFiles[update.taskID] = update.files
                    changed = true
                }
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
            _ = try? store?.save(task)
        }
    }

    private func markFailed(taskID: UUID, error: Error) {
        guard var task = tasks.first(where: { $0.id == taskID }) else { return }
        guard task.status == .queued || task.status == .downloading || task.status == .failed else {
            return
        }
        btWaitingTaskIDs.remove(taskID)
        let oldStatus = task.status
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
        if oldStatus != task.status {
            noteNotificationTransition(task: task, from: oldStatus)
        }
        notifyChange()
        startQueuedTasksIfNeeded()
    }

    private func noteNotificationTransition(task: DownloadTask, from oldStatus: DownloadTaskStatus) {
        guard oldStatus != task.status else { return }
        guard task.status == .completed || task.status == .failed else {
            lastNotifiedStatus.removeValue(forKey: task.id)
            return
        }
        if lastNotifiedStatus[task.id] == task.status {
            return
        }
        lastNotifiedStatus[task.id] = task.status
        notifier.notifyTaskFinished(task, preferences: preferences)
    }

    private func engine(for task: DownloadTask) -> DownloadEngine {
        task.kind == .http ? httpEngine : btEngine
    }

    // MARK: - Files

    /// 详情页文件列表：优先使用 BT 轮询的实时进度，否则回退到任务文件路径。
    func files(for task: DownloadTask) -> [DownloadFileProgress] {
        if let files = taskFiles[task.id], !files.isEmpty {
            return files
        }
        return task.filePaths.enumerated().map { index, path in
            let size = DownloadFileRules.existingFileSize(at: path) ?? 0
            return DownloadFileProgress(
                index: index,
                path: path,
                length: size,
                completedBytes: task.status == .completed ? size : 0,
                isWanted: true
            )
        }
    }

    /// 只有拿到 Transmission files 索引时才允许切换单文件 wanted。
    func canSelectFiles(for task: DownloadTask) -> Bool {
        task.isBitTorrent
            && task.status != .completed
            && preferences.enableBT
            && btState.isAvailable
            && taskFiles[task.id] != nil
    }

    func setFileWanted(taskID: UUID, path: String, wanted: Bool) {
        guard let task = tasks.first(where: { $0.id == taskID }),
              task.kind.isBitTorrent,
              task.status != .completed,
              preferences.enableBT,
              btState.isAvailable else {
            setLastError(NSLocalizedString("BT 内核不可用，无法修改文件选择。", comment: ""))
            notifyChange()
            return
        }
        guard var files = taskFiles[taskID],
              let index = files.firstIndex(where: { $0.path == path }) else {
            return
        }

        let original = files[index]
        files[index].isWanted = wanted
        taskFiles[taskID] = files
        notifyChange()

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.btEngine.setFilesWanted(
                    task: task,
                    indices: [original.index],
                    wanted: wanted
                )
            } catch {
                self.onMain {
                    if var current = self.taskFiles[taskID],
                       let currentIndex = current.firstIndex(where: { $0.path == path }) {
                        current[currentIndex].isWanted = original.isWanted
                        self.taskFiles[taskID] = current
                    }
                    self.setLastError(error.localizedDescription)
                    self.notifyChange()
                }
            }
        }
    }

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
        tasks.filter { $0.status.isActive }.count
    }

    func clearLastError() {
        lastErrorMessage = nil
        lastNoticeMessage = nil
        notifyChange()
    }

    private func setLastError(_ message: String) {
        lastErrorMessage = message
        lastNoticeMessage = nil
    }

    private func setLastNotice(_ message: String) {
        lastNoticeMessage = message
        lastErrorMessage = nil
    }

    // MARK: - Notification

    private func notifyChange() {
        if Thread.isMainThread {
            updateDockBadge()
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        } else {
            onMain { self.notifyChange() }
        }
    }

    private func updateDockBadge() {
        let count = activeTaskCount
        NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func onMainSync<T>(_ block: () -> T) -> T {
        if Thread.isMainThread {
            return block()
        }
        return DispatchQueue.main.sync(execute: block)
    }
}
