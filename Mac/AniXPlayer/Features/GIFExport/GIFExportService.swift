//
//  GIFExportService.swift
//  AniXPlayer
//
//  macOS：把视频片段导出为动图（会员功能）。
//
//  抓帧策略：
//  1. 本地且 AVFoundation 能解析的文件优先用 AVAssetImageGenerator（快）；
//  2. 其它情况用无头 MPV（独立实例，不依赖屏幕上的播放器），支持 MKV/HEVC/AV1
//     以及带 httpHeaders 的在线源；
//  3. 任一内核失败后回退到另一个内核；两个都失败会明确报错，不会生成空文件。
//
//  保存位置复用截图目录与 security-scoped bookmark。
//

import AVFoundation
import ANXLog
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - 输出格式

/// 动图输出格式。WebP 只有在当前 macOS 的 ImageIO 报告支持时才出现在选项里。
enum GIFExportFormat: String, CaseIterable {
    case gif
    case webp

    var displayName: String {
        switch self {
        case .gif:
            return "GIF"
        case .webp:
            return "WebP"
        }
    }

    var fileExtension: String {
        switch self {
        case .gif:
            return "gif"
        case .webp:
            return "webp"
        }
    }

    var utType: UTType {
        switch self {
        case .gif:
            return .gif
        case .webp:
            return .webP
        }
    }

    /// ImageIO 实际注册了对应的编码器才认为可用。
    var isSupportedByImageIO: Bool {
        let identifiers = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        switch self {
        case .gif:
            return identifiers.contains(UTType.gif.identifier)
        case .webp:
            return identifiers.contains(UTType.webP.identifier)
                || identifiers.contains("org.webmproject.webp")
        }
    }

    static var supportedFormats: [GIFExportFormat] {
        return allCases.filter { $0.isSupportedByImageIO }
    }
}

// MARK: - 配置

struct GIFExportConfiguration: Equatable {
    /// 片段时长（秒）。
    var duration: TimeInterval = 3
    /// 帧率。
    var framesPerSecond: Int = 10
    /// 输出最大宽度；高度按比例缩放。
    var maximumPixelWidth: CGFloat = 480
    /// 输出格式。
    var format: GIFExportFormat = .gif

    static let `default` = GIFExportConfiguration()

    static let allowedDurations: [TimeInterval] = [1, 2, 3, 5]
    static let allowedFrameRates: [Int] = [5, 10, 15]
    static let allowedWidths: [CGFloat] = [480, 640, 960]

    /// 帧数上限：5 秒 × 15fps = 75 帧。用于约束内存占用。
    static let maximumFrameCount = 75
    static let minimumClipDuration: TimeInterval = 0.5

    var normalized: GIFExportConfiguration {
        var copy = self
        copy.duration = min(max(duration, 1), 5)
        copy.framesPerSecond = min(max(framesPerSecond, 5), 15)
        copy.maximumPixelWidth = min(max(maximumPixelWidth, 240), 960)
        if !copy.format.isSupportedByImageIO {
            copy.format = .gif
        }
        return copy
    }

    /// 按片段时长估算帧数（与导出服务使用同一套取整/上限规则）。
    func estimatedFrameCount(for clipDuration: TimeInterval) -> Int {
        let normalized = self.normalized
        let usable = min(max(clipDuration, 0), normalized.duration)
        guard usable >= Self.minimumClipDuration else { return 0 }
        let count = Int((usable * Double(normalized.framesPerSecond)).rounded())
        return max(2, min(count, Self.maximumFrameCount))
    }
}

// MARK: - 结果与错误

struct GIFExportOutput {
    let url: URL
    let format: GIFExportFormat
    let frameCount: Int
    let frameRate: Int
}

enum GIFExportError: LocalizedError {
    case sourceUnavailable
    case unreadableVideo
    case clipTooShort
    case noFrames
    case incompleteCapture(captured: Int, expected: Int)
    case destinationUnavailable
    case encodingFailed
    case formatUnsupported
    case cancelled

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable:
            return NSLocalizedString("当前视频无法用于动图导出。", comment: "")
        case .unreadableVideo:
            return NSLocalizedString("无法读取当前视频，可能是不支持的编码格式。", comment: "")
        case .clipTooShort:
            return NSLocalizedString("当前位置之后没有足够的视频内容。", comment: "")
        case .noFrames:
            return NSLocalizedString("没有截取到可用画面。", comment: "")
        case .incompleteCapture(let captured, let expected):
            return String(
                format: NSLocalizedString("只截取到 %d/%d 帧，已取消导出，未生成动图。", comment: ""),
                captured,
                expected
            )
        case .destinationUnavailable:
            return NSLocalizedString("无法创建动图文件，请检查保存目录权限。", comment: "")
        case .encodingFailed:
            return NSLocalizedString("动图编码失败。", comment: "")
        case .formatUnsupported:
            return NSLocalizedString("当前系统不支持所选动图格式。", comment: "")
        case .cancelled:
            return NSLocalizedString("已取消动图导出。", comment: "")
        }
    }
}

// MARK: - 取消会话

/// 导出会话令牌。调用 `cancel()` 会让抓帧在下一帧前退出，并唤醒正在等待的
/// 无头 MPV 抓帧器。completion 只会回调一次。
final class GIFExportSession {

    private let lock = NSLock()
    private var cancelled = false
    private var cancelHandler: (() -> Void)?

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        if cancelled {
            lock.unlock()
            return
        }
        cancelled = true
        let handler = cancelHandler
        cancelHandler = nil
        lock.unlock()
        handler?()
    }

    func setCancelHandler(_ handler: @escaping () -> Void) {
        lock.lock()
        if cancelled {
            lock.unlock()
            handler()
            return
        }
        cancelHandler = handler
        lock.unlock()
    }

    func clearCancelHandler() {
        lock.lock()
        cancelHandler = nil
        lock.unlock()
    }

    func checkCancellation() throws {
        if isCancelled {
            throw GIFExportError.cancelled
        }
    }
}

// MARK: - 服务

final class GIFExportService {

    /// 启动导出。
    /// - Parameters:
    ///   - file: 当前播放的媒体；本地文件走 AVFoundation 快路径，其它走无头 MPV。
    ///   - startTime: 片段起始时间（秒）。
    ///   - mediaDuration: 当前播放器已知的总时长；无效时再尝试探测。
    ///   - configuration: 时长/帧率/宽度/格式。
    ///   - progress: 0...1，主线程回调。
    ///   - completion: 主线程回调。
    /// - Returns: 可用于取消的会话令牌。
    @discardableResult
    func export(
        file: File,
        startTime: TimeInterval,
        mediaDuration: TimeInterval,
        configuration: GIFExportConfiguration = .default,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<GIFExportOutput, Error>) -> Void
    ) -> GIFExportSession {
        let session = GIFExportSession()
        let config = configuration.normalized

        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<GIFExportOutput, Error>
            do {
                let output = try Self.performExport(
                    file: file,
                    startTime: startTime,
                    mediaDuration: mediaDuration,
                    configuration: config,
                    session: session,
                    progress: progress
                )
                result = .success(output)
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }

        return session
    }

    // MARK: - Export

    private static func performExport(
        file: File,
        startTime: TimeInterval,
        mediaDuration: TimeInterval,
        configuration: GIFExportConfiguration,
        session: GIFExportSession,
        progress: @escaping (Double) -> Void
    ) throws -> GIFExportOutput {
        defer { session.clearCancelHandler() }
        try session.checkCancellation()

        guard configuration.format.isSupportedByImageIO else {
            throw GIFExportError.formatUnsupported
        }

        let playableURL = (file.createMPVMedia()?.url ?? file.url)
        let isLocalSource = file.url.isFileURL && playableURL.isFileURL

        var duration = mediaDuration
        if !duration.isFinite || duration <= 0 {
            duration = probeDuration(of: playableURL)
        }
        guard duration.isFinite, duration > 0 else {
            throw GIFExportError.unreadableVideo
        }

        let start = min(max(startTime, 0), max(duration - 0.05, 0))
        let clipDuration = min(configuration.duration, duration - start)
        guard clipDuration >= GIFExportConfiguration.minimumClipDuration else {
            throw GIFExportError.clipTooShort
        }

        let fps = configuration.framesPerSecond
        let rawFrameCount = max(2, Int((clipDuration * Double(fps)).rounded()))
        let frameCount = min(rawFrameCount, GIFExportConfiguration.maximumFrameCount)
        let frameTimes = (0..<frameCount).map { index in
            min(start + (Double(index) / Double(fps)), max(duration - 0.1, 0))
        }

        var lastReported = 0.0
        let report: (Double, Bool) -> Void = { value, fromCapture in
            // 回退时抓帧进度会从 0 重新开始；对外保持单调递增。
            let base = fromCapture ? 0.02 + value * 0.84 : 0.88 + value * 0.12
            let clamped = min(max(base, lastReported), 1)
            guard clamped > lastReported || value >= 1 else { return }
            lastReported = clamped
            DispatchQueue.main.async {
                progress(clamped)
            }
        }

        var frames: [CGImage]?
        var failures: [Error] = []

        let avFoundationEligible = isLocalSource && AVFoundationFrameCapture.isSupported(fileURL: playableURL)

        if avFoundationEligible {
            do {
                frames = try AVFoundationFrameCapture.capture(
                    fileURL: playableURL,
                    frameTimes: frameTimes,
                    maximumPixelWidth: configuration.maximumPixelWidth,
                    session: session,
                    progress: { report($0, true) }
                )
            } catch {
                failures.append(error)
                ANX.logWarning(.player, "[GIF] AVFoundation 抓帧失败，尝试无头 MPV: \(error)")
            }
            if frames == nil && !session.isCancelled {
                do {
                    frames = try GIFMPVFrameCapture(
                        file: file,
                        maximumPixelWidth: configuration.maximumPixelWidth
                    ).capture(
                        frameTimes: frameTimes,
                        session: session,
                        progress: { report($0, true) }
                    )
                } catch {
                    failures.append(error)
                    ANX.logError(.player, "[GIF] 无头 MPV 抓帧失败: \(error)")
                }
            }
        } else {
            do {
                frames = try GIFMPVFrameCapture(
                    file: file,
                    maximumPixelWidth: configuration.maximumPixelWidth
                ).capture(
                    frameTimes: frameTimes,
                    session: session,
                    progress: { report($0, true) }
                )
            } catch {
                failures.append(error)
                ANX.logWarning(.player, "[GIF] 无头 MPV 抓帧失败，尝试 AVFoundation: \(error)")
            }
            if frames == nil && isLocalSource && !session.isCancelled {
                do {
                    frames = try AVFoundationFrameCapture.capture(
                        fileURL: playableURL,
                        frameTimes: frameTimes,
                        maximumPixelWidth: configuration.maximumPixelWidth,
                        session: session,
                        progress: { report($0, true) }
                    )
                } catch {
                    failures.append(error)
                    ANX.logError(.player, "[GIF] AVFoundation 回退抓帧失败: \(error)")
                }
            }
        }

        try session.checkCancellation()

        if session.isCancelled {
            throw GIFExportError.cancelled
        }

        guard let capturedFrames = frames, !capturedFrames.isEmpty else {
            // 优先展示无头 MPV 的错误（本地 MKV/HEVC/AV1、在线源的主要路径），
            // AVFoundation 的底层错误通常更含糊。
            if let mpvError = failures.first(where: { $0 is GIFMPVFrameCapture.CaptureError }) {
                throw mpvError
            }
            throw failures.last ?? GIFExportError.noFrames
        }

        guard capturedFrames.count == frameTimes.count else {
            throw GIFExportError.incompleteCapture(
                captured: capturedFrames.count,
                expected: frameTimes.count
            )
        }

        let outputURL = try write(
            frames: capturedFrames,
            source: file,
            format: configuration.format,
            frameRate: fps,
            session: session,
            progress: { report($0, false) }
        )

        if session.isCancelled {
            try? FileManager.default.removeItem(at: outputURL)
            throw GIFExportError.cancelled
        }

        report(1, false)
        return GIFExportOutput(
            url: outputURL,
            format: configuration.format,
            frameCount: capturedFrames.count,
            frameRate: fps
        )
    }

    private static func probeDuration(of url: URL) -> TimeInterval {
        guard url.isFileURL else { return 0 }
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        return duration.isFinite ? duration : 0
    }

    // MARK: - Encoding

    private static func write(
        frames: [CGImage],
        source: File,
        format: GIFExportFormat,
        frameRate: Int,
        session: GIFExportSession,
        progress: @escaping (Double) -> Void
    ) throws -> URL {
        let resolved: (url: URL, needsStopAccess: Bool)
        do {
            resolved = try SnapshotLocation.resolveAccessibleDirectory()
        } catch {
            throw GIFExportError.destinationUnavailable
        }
        defer {
            if resolved.needsStopAccess {
                resolved.url.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = makeFileName(source: source)
        let outputURL = resolved.url
            .appendingPathComponent(fileName)
            .appendingPathExtension(format.fileExtension)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            format.utType.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw GIFExportError.destinationUnavailable
        }

        do {
            let loopProperties = containerProperties(format: format, loopCount: 0)
            CGImageDestinationSetProperties(destination, loopProperties as CFDictionary)

            let delay = 1.0 / Double(max(frameRate, 1))
            let frameProperties = frameProperties(format: format, delay: delay)

            for (index, frame) in frames.enumerated() {
                try session.checkCancellation()
                CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
                progress(Double(index + 1) / Double(frames.count))
            }

            try session.checkCancellation()

            guard CGImageDestinationFinalize(destination) else {
                throw GIFExportError.encodingFailed
            }

            // 防止某些 ImageIO 编码器把动画 WebP/GIF 静默降级成单帧。
            if frames.count > 1 {
                let source = CGImageSourceCreateWithURL(outputURL as CFURL, nil)
                let encodedCount = source.map { CGImageSourceGetCount($0) } ?? 0
                guard encodedCount >= 2 else {
                    try? FileManager.default.removeItem(at: outputURL)
                    throw GIFExportError.encodingFailed
                }
            }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }

        return outputURL
    }

    private static func containerProperties(format: GIFExportFormat, loopCount: Int) -> [CFString: Any] {
        switch format {
        case .gif:
            return [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFLoopCount: loopCount
                ]
            ]
        case .webp:
            return [
                kCGImagePropertyWebPDictionary: [
                    kCGImagePropertyWebPLoopCount: loopCount
                ]
            ]
        }
    }

    private static func frameProperties(format: GIFExportFormat, delay: TimeInterval) -> [CFString: Any] {
        switch format {
        case .gif:
            return [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: delay,
                    kCGImagePropertyGIFUnclampedDelayTime: delay
                ]
            ]
        case .webp:
            return [
                kCGImagePropertyWebPDictionary: [
                    kCGImagePropertyWebPDelayTime: delay,
                    kCGImagePropertyWebPUnclampedDelayTime: delay
                ]
            ]
        }
    }

    private static func makeFileName(source: File) -> String {
        let rawName = source.fileName.isEmpty
            ? source.url.deletingPathExtension().lastPathComponent
            : (source.fileName as NSString).deletingPathExtension
        let baseName = rawName.isEmpty ? "Animated" : rawName

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let name = "\(baseName)_\(formatter.string(from: Date()))"
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

// MARK: - AVFoundation 抓帧

private enum AVFoundationFrameCapture {

    /// 只在本地文件上使用；确认有视频轨和有效时长后再交给 AVFoundation。
    static func isSupported(fileURL: URL) -> Bool {
        guard fileURL.isFileURL else { return false }
        let asset = AVURLAsset(url: fileURL)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else { return false }
        return !asset.tracks(withMediaType: .video).isEmpty
    }

    static func capture(
        fileURL: URL,
        frameTimes: [TimeInterval],
        maximumPixelWidth: CGFloat,
        session: GIFExportSession,
        progress: (Double) -> Void
    ) throws -> [CGImage] {
        let asset = AVURLAsset(url: fileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: maximumPixelWidth, height: maximumPixelWidth)

        var frames: [CGImage] = []
        frames.reserveCapacity(frameTimes.count)

        for (index, seconds) in frameTimes.enumerated() {
            try session.checkCancellation()

            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            var image: CGImage?
            do {
                image = try generator.copyCGImage(at: time, actualTime: nil)
            } catch {
                // 单帧失败时放宽容差重试一次；仍失败则整体失败，避免生成缺帧动图。
                generator.requestedTimeToleranceBefore = CMTime(seconds: 0.25, preferredTimescale: 600)
                generator.requestedTimeToleranceAfter = CMTime(seconds: 0.25, preferredTimescale: 600)
                do {
                    image = try generator.copyCGImage(at: time, actualTime: nil)
                } catch {
                    throw GIFExportError.incompleteCapture(
                        captured: frames.count,
                        expected: frameTimes.count
                    )
                }
            }

            guard let image = image else {
                throw GIFExportError.incompleteCapture(captured: frames.count, expected: frameTimes.count)
            }
            frames.append(image)
            progress(Double(index + 1) / Double(frameTimes.count))
        }

        try session.checkCancellation()
        return frames
    }
}
