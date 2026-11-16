//
//  GIFExportService.swift
//  AniXPlayer
//
//  macOS：把本地视频的当前片段导出为动图（会员功能）。
//
//  首版只处理 AVFoundation 能解码的本地文件；VLC/MPV 专有格式或远程流
//  会明确报错，不静默生成空文件。保存位置复用截图目录与 security-scoped bookmark。
//

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct GIFExportConfiguration: Equatable {
    /// 片段时长（秒）。
    var duration: TimeInterval = 3
    /// 帧率。
    var framesPerSecond: Int = 10
    /// 输出最大宽度；高度按比例缩放。
    var maximumPixelWidth: CGFloat = 480

    static let `default` = GIFExportConfiguration()

    var normalized: GIFExportConfiguration {
        var copy = self
        copy.duration = min(max(duration, 1), 10)
        copy.framesPerSecond = min(max(framesPerSecond, 5), 20)
        copy.maximumPixelWidth = min(max(maximumPixelWidth, 240), 960)
        return copy
    }
}

enum GIFExportError: LocalizedError {
    case remoteOrMissingFile
    case unreadableVideo
    case clipTooShort
    case noFrames
    case destinationUnavailable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .remoteOrMissingFile:
            return NSLocalizedString("当前视频不是本地文件，暂不支持导出动图。", comment: "")
        case .unreadableVideo:
            return NSLocalizedString("无法读取当前视频，可能是不支持的编码格式。", comment: "")
        case .clipTooShort:
            return NSLocalizedString("当前位置之后没有足够的视频内容。", comment: "")
        case .noFrames:
            return NSLocalizedString("没有截取到可用画面。", comment: "")
        case .destinationUnavailable:
            return NSLocalizedString("无法创建动图文件，请检查保存目录权限。", comment: "")
        case .encodingFailed:
            return NSLocalizedString("动图编码失败。", comment: "")
        }
    }
}

final class GIFExportService {

    /// - Parameters:
    ///   - videoURL: 本地视频地址。
    ///   - startTime: 起始时间（秒）。
    ///   - configuration: 时长/帧率/宽度。
    ///   - progress: 0...1，后台队列回调。
    ///   - completion: 主线程回调，成功返回 GIF 地址。
    func export(
        videoURL: URL,
        startTime: TimeInterval,
        configuration: GIFExportConfiguration = .default,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard videoURL.isFileURL else {
            completion(.failure(GIFExportError.remoteOrMissingFile))
            return
        }

        let config = configuration.normalized
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<URL, Error>
            do {
                let url = try Self.performExport(
                    videoURL: videoURL,
                    startTime: startTime,
                    configuration: config,
                    progress: progress
                )
                result = .success(url)
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    // MARK: - Export

    private static func performExport(
        videoURL: URL,
        startTime: TimeInterval,
        configuration: GIFExportConfiguration,
        progress: @escaping (Double) -> Void
    ) throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else {
            throw GIFExportError.unreadableVideo
        }

        let clipDuration = min(configuration.duration, max(0, duration - startTime))
        guard clipDuration >= 0.5 else {
            throw GIFExportError.clipTooShort
        }

        let fps = max(1, configuration.framesPerSecond)
        let frameCount = max(2, Int((clipDuration * Double(fps)).rounded()))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(
            width: configuration.maximumPixelWidth,
            height: configuration.maximumPixelWidth
        )

        var frames: [CGImage] = []
        frames.reserveCapacity(frameCount)

        for index in 0..<frameCount {
            try Task.checkCancellation()
            let seconds = startTime + (Double(index) / Double(fps))
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            do {
                let image = try generator.copyCGImage(at: time, actualTime: nil)
                frames.append(image)
            } catch {
                // 单帧失败不直接终止：保留已取得的帧；全部失败时再报错。
                continue
            }
            progress(Double(index + 1) / Double(frameCount))
        }

        guard !frames.isEmpty else {
            throw GIFExportError.noFrames
        }

        let resolved = try SnapshotLocation.resolveAccessibleDirectory()
        defer {
            if resolved.needsStopAccess {
                resolved.url.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = makeFileName(source: videoURL)
        let outputURL = resolved.url.appendingPathComponent(fileName).appendingPathExtension("gif")

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw GIFExportError.destinationUnavailable
        }

        let loopProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, loopProperties as CFDictionary)

        let delay = 1.0 / Double(fps)
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay,
                kCGImagePropertyGIFUnclampedDelayTime: delay
            ]
        ]
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: outputURL)
            throw GIFExportError.encodingFailed
        }

        return outputURL
    }

    private static func makeFileName(source: URL) -> String {
        let baseName = source.deletingPathExtension().lastPathComponent
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let name = "\(baseName)_\(formatter.string(from: Date()))"
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
