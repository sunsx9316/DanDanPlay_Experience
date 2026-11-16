//
//  LocalLibraryMatcher.swift
//  AniXPlayer
//
//  macOS：调用现有 MatchNetworkHandle 匹配本地媒体库文件。
//  最多 2 个并发；失败只记录，不阻塞扫描/浏览。
//

import Foundation
import ANXLog

struct LocalLibraryMatchSummary: Equatable {
    var candidateCount: Int = 0
    var matchedCount: Int = 0
    var failedCount: Int = 0
    var cancelled: Bool = false

    var hasFailures: Bool { failedCount > 0 }
}

final class LocalLibraryMatcher {

    private let store: LocalLibraryStore
    private let lock = NSLock()
    private var runningTask: Task<Void, Never>?
    private let maximumConcurrentMatches = 2

    init(store: LocalLibraryStore) {
        self.store = store
    }

    var isMatching: Bool {
        lock.lock()
        defer { lock.unlock() }
        return runningTask != nil
    }

    /// 匹配给定文件（通常来自 store.unmatchedFiles()）。
    /// `progress` / `completion` 在主线程回调。
    func match(
        files: [LocalLibraryFile],
        progress: @escaping (_ completed: Int, _ total: Int) -> Void,
        completion: @escaping (LocalLibraryMatchSummary) -> Void
    ) {
        lock.lock()
        guard runningTask == nil else {
            lock.unlock()
            return
        }
        lock.unlock()

        guard !files.isEmpty else {
            let summary = LocalLibraryMatchSummary(candidateCount: 0)
            DispatchQueue.main.async { completion(summary) }
            return
        }

        let task = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let summary = await self.performMatch(files: files, progress: progress)
            self.clearRunningTask()
            await MainActor.run {
                completion(summary)
            }
        }

        lock.lock()
        runningTask = task
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        let task = runningTask
        lock.unlock()
        task?.cancel()
    }

    private func clearRunningTask() {
        lock.lock()
        runningTask = nil
        lock.unlock()
    }

    // MARK: - Work

    private struct Attempt {
        var outcome: LocalLibraryMatchOutcome
        var error: Error?
    }

    private struct WorkerResult {
        var matched: Int = 0
        var failed: Int = 0
        var cancelled: Bool = false
    }

    private actor Cursor {
        private let files: [LocalLibraryFile]
        private var index = 0

        init(files: [LocalLibraryFile]) {
            self.files = files
        }

        func next() -> (Int, LocalLibraryFile)? {
            guard index < files.count else { return nil }
            let current = index
            index += 1
            return (current, files[current])
        }
    }

    private func performMatch(
        files: [LocalLibraryFile],
        progress: @escaping (Int, Int) -> Void
    ) async -> LocalLibraryMatchSummary {
        let cursor = Cursor(files: files)
        let total = files.count
        let workerCount = min(maximumConcurrentMatches, total)
        let completionCounter = LockedCounter()
        var summary = LocalLibraryMatchSummary(candidateCount: total)

        await withTaskGroup(of: WorkerResult.self) { group in
            for _ in 0..<workerCount {
                group.addTask { [store] in
                    var result = WorkerResult()
                    while let (_, file) = await cursor.next() {
                        if Task.isCancelled {
                            result.cancelled = true
                            return result
                        }

                        let attempt = await Self.matchNetwork(file: file)
                        if attempt.error != nil {
                            result.failed += 1
                        } else if attempt.outcome.isMatched {
                            result.matched += 1
                        } else {
                            result.failed += 1
                        }

                        // 失败也要写回 isMatched=false，后续可以重试。
                        try? store.updateMatch(fileId: file.id, outcome: attempt.outcome)

                        let done = completionCounter.increment()
                        await MainActor.run {
                            progress(done, total)
                        }
                    }
                    return result
                }
            }

            for await worker in group {
                summary.matchedCount += worker.matched
                summary.failedCount += worker.failed
                summary.cancelled = summary.cancelled || worker.cancelled
            }
        }

        let completed = summary.matchedCount + summary.failedCount
        let matchedCount = summary.matchedCount
        let failedCount = summary.failedCount
        let wasCancelled = summary.cancelled

        await MainActor.run {
            progress(completed, total)
        }
        ANX.logInfo(.UI, "[LocalLibrary] 匹配完成 matched=\(matchedCount) failed=\(failedCount) cancelled=\(wasCancelled)")
        return LocalLibraryMatchSummary(
            candidateCount: total,
            matchedCount: matchedCount,
            failedCount: failedCount,
            cancelled: wasCancelled
        )
    }

    private static func matchNetwork(file: LocalLibraryFile) async -> Attempt {
        await withCheckedContinuation { continuation in
            let localFile = LocalFile(with: URL(fileURLWithPath: file.path))
            MatchNetworkHandle.match(with: localFile) { collection, error in
                if let error {
                    continuation.resume(returning: Attempt(outcome: .noResult, error: error))
                    return
                }
                let outcome = LocalLibraryMatchEvaluator.evaluate(collection)
                continuation.resume(returning: Attempt(outcome: outcome, error: nil))
            }
        }
    }
}

private final class LockedCounter {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
