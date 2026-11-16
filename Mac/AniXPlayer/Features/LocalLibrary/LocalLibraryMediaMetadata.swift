//
//  LocalLibraryMediaMetadata.swift
//  AniXPlayer
//
//  macOS：本地媒体库的缩略图 / 时长 / 分辨率探测。
//  AVFoundation 只支持它能解码的容器；MKV/AV1 等失败时保持 nil，
//  UI 回退到远程海报或扩展名占位。全部工作在后台队列，主线程只收结果。
//

import Cocoa
import AVFoundation
import CryptoKit

// MARK: - Playback access

/// 播放时需要保持 security-scoped access。扫描结束后访问会停止，
/// 但独立播放器窗口仍要读取文件，所以这里按文件夹缓存并保持到进程结束。
final class LocalLibraryFolderAccess {

    static let shared = LocalLibraryFolderAccess()

    private let lock = NSLock()
    private var activeURLs: [Int64: URL] = [:]

    private init() {}

    @discardableResult
    func ensureAccess(folder: LocalLibraryFolder) -> Bool {
        lock.lock()
        if let url = activeURLs[folder.id],
           FileManager.default.isReadableFile(atPath: url.path) {
            lock.unlock()
            return true
        }
        lock.unlock()

        let url = resolvedURL(for: folder) ?? folder.fileURL
        let started = url.startAccessingSecurityScopedResource()
        let readable = FileManager.default.isReadableFile(atPath: url.path)
        guard started || readable else { return false }

        lock.lock()
        activeURLs[folder.id] = url
        lock.unlock()
        return true
    }

    func resolvedURL(for folder: LocalLibraryFolder) -> URL? {
        guard let bookmark = folder.bookmark else { return nil }
        var stale = false
        if let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) {
            return url
        }
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }
}

// MARK: - Thumbnail provider

struct LocalLibraryThumbnailResult {
    var image: NSImage?
    var metadata: LocalLibraryMediaMetadata
}

final class LocalLibraryThumbnailProvider {

    private struct Callback {
        let token: UUID
        let completion: (LocalLibraryThumbnailResult) -> Void
    }

    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.anixplayer.local-library.thumbnail"
        queue.maxConcurrentOperationCount = 2
        queue.qualityOfService = .utility
        return queue
    }()

    private let lock = NSLock()
    private var memoryCache: [String: LocalLibraryThumbnailResult] = [:]
    private var pending: [String: [Callback]] = [:]
    private var tokenKeys: [UUID: String] = [:]
    private var operations: [String: Operation] = [:]

    private let store: LocalLibraryStore?
    private let cacheDirectory: URL?
    private var folders: [Int64: LocalLibraryFolder] = [:]

    init(store: LocalLibraryStore?) {
        self.store = store
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base
            .appendingPathComponent("AniXPlayer", isDirectory: true)
            .appendingPathComponent("LocalLibraryThumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cacheDirectory = directory
    }

    /// 返回 token；cell 复用/消失时调用 `cancel(token)`。
    @discardableResult
    func request(
        for file: LocalLibraryFile,
        completion: @escaping (LocalLibraryThumbnailResult) -> Void
    ) -> UUID {
        let token = UUID()
        let key = Self.cacheKey(for: file)

        lock.lock()
        if let cached = memoryCache[key] {
            lock.unlock()
            DispatchQueue.main.async { completion(cached) }
            return token
        }
        if pending[key] != nil {
            pending[key]?.append(Callback(token: token, completion: completion))
            tokenKeys[token] = key
            lock.unlock()
            return token
        }
        pending[key] = [Callback(token: token, completion: completion)]
        tokenKeys[token] = key
        lock.unlock()

        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self else { return }
            if operation?.isCancelled == true {
                self.finish(key: key, result: LocalLibraryThumbnailResult(
                    image: nil,
                    metadata: file.mediaMetadata
                ))
                return
            }
            let result = self.generate(file: file, cacheKey: key)
            self.finish(key: key, result: result)
        }

        lock.lock()
        operations[key] = operation
        lock.unlock()
        queue.addOperation(operation)
        return token
    }

    func cancel(_ token: UUID) {
        lock.lock()
        guard let key = tokenKeys.removeValue(forKey: token) else {
            lock.unlock()
            return
        }
        pending[key]?.removeAll(where: { $0.token == token })
        let shouldCancel = pending[key]?.isEmpty ?? true
        if shouldCancel {
            pending.removeValue(forKey: key)
            operations.removeValue(forKey: key)?.cancel()
        }
        lock.unlock()
    }

    /// 让缩略图探测能在沙盒中读取 security-scoped 文件夹。
    func updateFolders(_ folders: [LocalLibraryFolder]) {
        lock.lock()
        self.folders = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        lock.unlock()
    }

    // MARK: - Private

    private func finish(key: String, result: LocalLibraryThumbnailResult) {
        lock.lock()
        let callbacks = pending.removeValue(forKey: key) ?? []
        for callback in callbacks {
            tokenKeys.removeValue(forKey: callback.token)
        }
        operations.removeValue(forKey: key)
        if !callbacks.isEmpty {
            memoryCache[key] = result
            // 防止长时间浏览后无限增长；简单上限即可。
            if memoryCache.count > 400 {
                memoryCache.removeAll(keepingCapacity: true)
            }
        }
        lock.unlock()

        guard !callbacks.isEmpty else { return }
        DispatchQueue.main.async {
            for callback in callbacks {
                callback.completion(result)
            }
        }
    }

    private func generate(file: LocalLibraryFile, cacheKey: String) -> LocalLibraryThumbnailResult {
        var metadata = file.mediaMetadata
        let cacheURL = cacheDirectory?.appendingPathComponent(cacheKey + ".jpg")
        let cachedImage = cacheURL.flatMap { NSImage(contentsOf: $0) }

        if let cachedImage, !metadata.isEmpty {
            return LocalLibraryThumbnailResult(image: cachedImage, metadata: metadata)
        }

        lock.lock()
        let folder = folders[file.folderId]
        lock.unlock()
        if let folder {
            _ = LocalLibraryFolderAccess.shared.ensureAccess(folder: folder)
        }

        guard FileManager.default.fileExists(atPath: file.path) else {
            return LocalLibraryThumbnailResult(image: cachedImage, metadata: metadata)
        }

        let asset = AVURLAsset(url: file.fileURL)
        let duration = CMTimeGetSeconds(asset.duration)
        if duration.isFinite, duration > 0 {
            metadata.duration = duration
        }

        if let track = asset.tracks(withMediaType: .video).first {
            let transformed = track.naturalSize.applying(track.preferredTransform)
            let width = Int(abs(transformed.width).rounded())
            let height = Int(abs(transformed.height).rounded())
            if width > 0, height > 0 {
                metadata.width = width
                metadata.height = height
            }
        }

        if metadata != file.mediaMetadata {
            _ = try? store?.updateMediaMetadata(
                fileId: file.id,
                duration: metadata.duration,
                width: metadata.width,
                height: metadata.height
            )
        }

        var image = cachedImage
        if image == nil, let duration = metadata.duration, duration > 0 {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 960)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)

            // 取 10% 或至少 1 秒，避免片头黑屏；不超过片尾。
            let target = min(max(1, duration * 0.1), max(0, duration - 0.1))
            if let cgImage = try? generator.copyCGImage(
                at: CMTime(seconds: target, preferredTimescale: 600),
                actualTime: nil
            ) {
                image = NSImage(cgImage: cgImage, size: .zero)
            }
        }

        if let image, let cacheURL, cachedImage == nil {
            write(image: image, to: cacheURL)
        }

        return LocalLibraryThumbnailResult(image: image, metadata: metadata)
    }

    private func write(image: NSImage, to url: URL) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    static func cacheKey(for file: LocalLibraryFile) -> String {
        let raw = "\(file.path)|\(Int64(file.modifiedAt.timeIntervalSince1970))|\(file.fileSize)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
