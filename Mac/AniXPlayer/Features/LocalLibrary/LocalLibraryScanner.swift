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

    private func performScan(
        folders: [LocalLibraryFolder],
        progress: @escaping (LocalLibraryScanProgress) -> Void
    ) -> LocalLibraryScanSummary {
        var summary = LocalLibraryScanSummary()
        var accesses: [FolderAccess] = []
        var jobs: [ScanJob] = []
        var enumeratedFolderIds: Set<Int64> = []

        for folder in folders {
            if isCancelled {
                summary.cancelled = true
                break
            }

            let access = makeAccess(for: folder)
            accesses.append(access)

            do {
                let items = try LocalLibraryScanRules.enumerateVideoFiles(in: access.url)
                enumeratedFolderIds.insert(folder.id)
                jobs.append(contentsOf: items.map { ScanJob(folder: folder, item: $0) })
            } catch {
                summary.failed += 1
                if summary.errorMessage == nil {
                    summary.errorMessage = String(
                        format: NSLocalizedString("无法读取文件夹「%@」：%@", comment: ""),
                        folder.name,
                        error.localizedDescription
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

        for job in jobs {
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
                continue
            }

            var hash: String?
            let hashResult = Self.hashForFile(at: URL(fileURLWithPath: path))
            switch hashResult {
            case .success(let value):
                hash = value
                summary.hashed += 1
            case .failure(let error):
                summary.failed += 1
                if summary.errorMessage == nil {
                    summary.errorMessage = String(
                        format: NSLocalizedString("计算文件哈希失败「%@」：%@", comment: ""),
                        job.item.fileName,
                        error.localizedDescription
                    )
                }
            }

            let file = LocalLibraryFile.makeScanned(
                folderId: job.folder.id,
                path: path,
                fileName: job.item.fileName,
                fileSize: job.item.fileSize,
                modifiedAt: job.item.modifiedAt,
                hash: hash,
                existingId: existing?.id,
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
            let paths = Set(jobs.filter { $0.folder.id == folder.id }.map { $0.item.path })
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
        fileManager: FileManager = .default
    ) throws -> [LocalLibraryScanItem] {
        try LocalLibraryScanRules.enumerateVideoFiles(in: root, fileManager: fileManager)
    }

    // MARK: - Hash

    /// 前 16MB 的 MD5；复用 LocalFile 的实现，保持与播放器匹配参数一致。
    static func hashForFile(at url: URL) -> Result<String, Error> {
        let file = LocalFile(with: url)
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var output: Result<String, Error> = .failure(
            NSError(
                domain: "LocalLibraryScanner",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("哈希计算超时", comment: "")]
            )
        )

        file.getFileHashWithProgress(nil) { result in
            lock.lock()
            output = result
            lock.unlock()
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 120) == .timedOut {
            return output
        }

        lock.lock()
        defer { lock.unlock() }
        return output
    }
}
