//
//  LocalLibraryScanner.swift
//  AniXPlayer
//
//  macOS：本地媒体库文件夹扫描、增量判断与哈希计算。
//

import Foundation
import ANXLog

final class LocalLibraryScanner {

    private let store: LocalLibraryStore
    private let workQueue = DispatchQueue(label: "com.anixplayer.local-library.scanner", qos: .utility)
    private let stateLock = NSLock()

    private var cancelRequested = false
    private var scanning = false

    init(store: LocalLibraryStore) {
        self.store = store
    }

    var isScanning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return scanning
    }

    /// 在后台扫描所有根文件夹。
    /// `progress` / `completion` 都在主线程回调。
    func startScan(
        folders: [LocalLibraryFolder],
        progress: @escaping (LocalLibraryScanProgress) -> Void,
        completion: @escaping (LocalLibraryScanSummary) -> Void
    ) {
        stateLock.lock()
        if scanning {
            stateLock.unlock()
            return
        }
        scanning = true
        cancelRequested = false
        stateLock.unlock()

        workQueue.async { [weak self] in
            guard let self else { return }
            let summary = self.performScan(folders: folders, progress: progress)
            self.stateLock.lock()
            self.scanning = false
            self.stateLock.unlock()
            DispatchQueue.main.async {
                completion(summary)
            }
        }
    }

    func cancel() {
        stateLock.lock()
        cancelRequested = true
        stateLock.unlock()
    }

    // MARK: - Scan

    private struct FolderAccess {
        let folder: LocalLibraryFolder
        let url: URL
        let didStartAccessing: Bool
    }

    private struct ScanJob {
        let folder: LocalLibraryFolder
        let item: LocalLibraryScanItem
    }

    /// 单个文件的哈希等待上限。原先 120 秒会让网络卷/损坏文件长时间卡住取消。
    static let hashTimeout: TimeInterval = 20

    private func performScan(
        folders: [LocalLibraryFolder],
        progress: @escaping (LocalLibraryScanProgress) -> Void
    ) -> LocalLibraryScanSummary {
        var summary = LocalLibraryScanSummary()
        var accesses: [FolderAccess] = []
        var jobs: [ScanJob] = []
        var enumeratedFolderIds: Set<Int64> = []
        var enumeratedPaths: [Int64: Set<String>] = [:]
        var seenPaths: Set<String> = []

        for folder in folders {
            if isCancelled {
                summary.cancelled = true
                break
            }

            let access = makeAccess(for: folder)
            accesses.append(access)

            do {
                let items = try LocalLibraryScanRules.enumerateVideoFiles(
                    in: access.url,
                    shouldCancel: { [weak self] in self?.isCancelled ?? false }
                )
                enumeratedFolderIds.insert(folder.id)
                enumeratedPaths[folder.id] = Set(items.map(\.path))
                for item in items where !seenPaths.contains(item.path) {
                    seenPaths.insert(item.path)
                    jobs.append(ScanJob(folder: folder, item: item))
                }
            } catch is CancellationError {
                summary.cancelled = true
                break
            } catch {
                summary.failed += 1
                let message = error.localizedDescription
                summary.folderFailures.append(
                    LocalLibraryScanFailure(
                        folderId: folder.id,
                        folderPath: folder.path,
                        message: message
                    )
                )
                if summary.errorMessage == nil {
                    summary.errorMessage = String(
                        format: NSLocalizedString("无法读取文件夹「%@」：%@", comment: ""),
                        folder.name,
                        message
                    )
                }
            }
        }

        defer {
            for access in accesses where access.didStartAccessing {
                access.url.stopAccessingSecurityScopedResource()
            }
        }

        let total = jobs.count
        var scanned = 0
        var lastReport = Date.distantPast

        func report(_ item: LocalLibraryScanItem?, force: Bool = false) {
            let now = Date()
            guard force || now.timeIntervalSince(lastReport) >= 0.08 else { return }
            lastReport = now
            let value = LocalLibraryScanProgress(
                scanned: scanned,
                total: total,
                currentFileName: item?.fileName ?? ""
            )
            DispatchQueue.main.async {
                progress(value)
            }
        }

        report(nil, force: true)

        scanLoop: for job in jobs {
            if isCancelled {
                summary.cancelled = true
                break
            }

            scanned += 1
            report(job.item)

            let path = job.item.path
            let existing = try? store.file(path: path)
            guard LocalLibraryScanRules.needsUpdate(
                existing: existing,
                fileSize: job.item.fileSize,
                modifiedAt: job.item.modifiedAt
            ) else {
                summary.unchanged += 1
                if isCancelled {
                    summary.cancelled = true
                    break
                }
                continue
            }

            var hash: String?
            let hashResult = Self.hashForFile(
                at: URL(fileURLWithPath: path),
                timeout: Self.hashTimeout,
                isCancelled: { [weak self] in self?.isCancelled ?? false }
            )
            switch hashResult {
            case .success(let value):
                hash = value
                summary.hashed += 1
            case .failure(let error):
                if error is CancellationError {
                    summary.cancelled = true
                    break scanLoop
                }
                summary.failed += 1
                if summary.errorMessage == nil {
                    summary.errorMessage = String(
                        format: NSLocalizedString("计算文件哈希失败「%@」：%@", comment: ""),
                        job.item.fileName,
                        error.localizedDescription
                    )
                }
            }

            if isCancelled {
                summary.cancelled = true
                break
            }

            let file = LocalLibraryFile.makeScanned(
                folderId: job.folder.id,
                path: path,
                fileName: job.item.fileName,
                fileSize: job.item.fileSize,
                modifiedAt: job.item.modifiedAt,
                hash: hash,
                existing: existing,
                now: Date()
            )

            do {
                try store.saveFile(file)
                if existing == nil {
                    summary.added += 1
                } else {
                    summary.updated += 1
                }
            } catch {
                summary.failed += 1
                if summary.errorMessage == nil {
                    summary.errorMessage = error.localizedDescription
                }
            }
        }

        // 已完整枚举的文件夹：DB 中存在但磁盘上已消失的记录标记为 missing。
        for folder in folders where enumeratedFolderIds.contains(folder.id) {
            let paths = enumeratedPaths[folder.id] ?? []
            if let count = try? store.markMissing(folderId: folder.id, keepingPaths: paths), count > 0 {
                summary.markedMissing += count
            }
        }

        report(nil, force: true)
        ANX.logInfo(.UI, "[LocalLibrary] 扫描完成 added=\(summary.added) updated=\(summary.updated) unchanged=\(summary.unchanged) missing=\(summary.markedMissing) failed=\(summary.failed) cancelled=\(summary.cancelled)")
        return summary
    }

    private var isCancelled: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return cancelRequested
    }

    private func makeAccess(for folder: LocalLibraryFolder) -> FolderAccess {
        var resolvedURL: URL?
        var stale = false

        if let bookmark = folder.bookmark {
            resolvedURL = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        }

        if resolvedURL == nil {
            resolvedURL = try? URL(
                resolvingBookmarkData: folder.bookmark ?? Data(),
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        }

        let url = resolvedURL ?? folder.fileURL
        let didStart = url.startAccessingSecurityScopedResource()

        if stale, let refreshed = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            try? store.updateFolderBookmark(id: folder.id, bookmark: refreshed)
        }

        return FolderAccess(folder: folder, url: url, didStartAccessing: didStart)
    }

    // MARK: - Enumeration (also used by tests)

    /// 递归枚举视频文件；跳过隐藏文件、包内容和非常规文件。
    static func enumerateVideoFiles(
        in root: URL,
        fileManager: FileManager = .default,
        shouldCancel: (() -> Bool)? = nil
    ) throws -> [LocalLibraryScanItem] {
        try LocalLibraryScanRules.enumerateVideoFiles(
            in: root,
            fileManager: fileManager,
            shouldCancel: shouldCancel
        )
    }

    // MARK: - Hash

    /// 前 16MB 的 MD5；复用 LocalFile 的实现，保持与播放器匹配参数一致。
    /// 等待期间每 0.1 秒检查取消，避免一个慢文件让扫描无法停止。
    static func hashForFile(
        at url: URL,
        timeout: TimeInterval = 20,
        isCancelled: () -> Bool = { false }
    ) -> Result<String, Error> {
        if isCancelled() {
            return .failure(CancellationError())
        }

        let file = LocalFile(with: url)
        let semaphore = DispatchSemaphore(value: 0)
        let box = LocalLibraryHashBox()

        file.getFileHashWithProgress(nil) { result in
            box.set(result)
            semaphore.signal()
        }

        let deadline = Date().addingTimeInterval(max(0.1, timeout))
        while true {
            if semaphore.wait(timeout: .now() + 0.1) == .success {
                break
            }
            if isCancelled() {
                return .failure(CancellationError())
            }
            if Date() >= deadline {
                return .failure(
                    NSError(
                        domain: "LocalLibraryScanner",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("哈希计算超时", comment: "")]
                    )
                )
            }
        }

        return box.value
    }
}

/// 哈希回调与超时/取消路径可能并发访问；用锁保护结果。
private final class LocalLibraryHashBox {
    private let lock = NSLock()
    private var stored: Result<String, Error> = .failure(
        NSError(
            domain: "LocalLibraryScanner",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("哈希计算失败", comment: "")]
        )
    )

    func set(_ result: Result<String, Error>) {
        lock.lock()
        stored = result
        lock.unlock()
    }

    var value: Result<String, Error> {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}
