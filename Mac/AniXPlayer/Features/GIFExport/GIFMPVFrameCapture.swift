//
//  GIFMPVFrameCapture.swift
//  AniXPlayer
//
//  macOS：无头 MPV 抓帧器，用于 AVFoundation 解不了的本地文件（MKV/HEVC/AV1）
//  以及带 httpHeaders 的在线源。复用 MPVFrameRenderer，不依赖屏幕上的播放器。
//
//  一个实例只加载一次媒体，之后逐帧 seek + 渲染；每帧都有超时和取消检查。
//

import AVFoundation
import ANXLog
import CoreGraphics
import Foundation
import MPVFramework

final class GIFMPVFrameCapture {

    enum CaptureError: LocalizedError {
        case createFailed
        case loadFailed
        case loadTimedOut
        case frameTimedOut
        case frameUnavailable
        case noVideoTrack
        case cancelled

        var errorDescription: String? {
            switch self {
            case .createFailed:
                return NSLocalizedString("无法创建视频解码器。", comment: "")
            case .loadFailed:
                return NSLocalizedString("无法加载当前视频。", comment: "")
            case .loadTimedOut:
                return NSLocalizedString("加载视频超时，请稍后重试。", comment: "")
            case .frameTimedOut, .frameUnavailable:
                return NSLocalizedString("截取画面超时。", comment: "")
            case .noVideoTrack:
                return NSLocalizedString("当前视频没有可用的画面。", comment: "")
            case .cancelled:
                return NSLocalizedString("已取消动图导出。", comment: "")
            }
        }
    }

    private let file: File
    private let maximumPixelWidth: CGFloat
    private let queue = DispatchQueue(label: "com.anixplayer.gif.mpv.capture", qos: .userInitiated)
    private let renderer = MPVFrameRenderer()

    private var mpv: MPV?
    private var media: MPVMedia?
    private var frameTimes: [TimeInterval] = []
    private var frames: [CGImage] = []
    private var currentIndex = 0
    private var currentTarget: TimeInterval?
    private var isLoaded = false
    private var isSeekCompleted = false
    private var isFinished = false
    private var isRemoteSource = false
    private var frameRenderRetries = 0
    private var videoSizeWaitCount = 0

    private var session: GIFExportSession?
    private var progress: ((Double) -> Void)?
    private var loadTimeoutItem: DispatchWorkItem?
    private var frameTimeoutItem: DispatchWorkItem?
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Result<[CGImage], Error> = .failure(CaptureError.createFailed)

    private let localLoadTimeout: TimeInterval = 15
    private let remoteLoadTimeout: TimeInterval = 30
    private let localFrameTimeout: TimeInterval = 8
    private let remoteFrameTimeout: TimeInterval = 15

    init(file: File, maximumPixelWidth: CGFloat) {
        self.file = file
        self.maximumPixelWidth = max(240, min(maximumPixelWidth, 960))
    }

    /// 同步抓帧（在调用方的后台线程上阻塞）。进度回调在内部串行队列上触发。
    func capture(
        frameTimes: [TimeInterval],
        session: GIFExportSession,
        progress: @escaping (Double) -> Void
    ) throws -> [CGImage] {
        guard !frameTimes.isEmpty else { throw GIFExportError.noFrames }

        queue.sync {
            self.frameTimes = frameTimes
            self.session = session
            self.progress = progress
            self.startOnQueue()
        }

        // 取消时唤醒等待，避免调用方卡在已经终止的 MPV 实例上。
        session.setCancelHandler { [weak self] in
            self?.abort()
        }

        let waitResult = semaphore.wait(timeout: .now() + max(60, Double(frameTimes.count) * 20))
        if waitResult == .timedOut {
            queue.sync {
                if !self.isFinished {
                    self.finish(.failure(CaptureError.frameTimedOut))
                }
            }
        }

        switch result {
        case .success(let frames):
            return frames
        case .failure(let error):
            throw error
        }
    }

    deinit {
        loadTimeoutItem?.cancel()
        frameTimeoutItem?.cancel()
        renderer.terminate()
        mpv?.quit()
        mpv = nil
    }

    // MARK: - 启动与加载

    private func startOnQueue() {
        guard !isFinished else { return }
        guard let media = file.createMPVMedia(), let mpv = MPV() else {
            finish(.failure(CaptureError.createFailed))
            return
        }
        self.media = media
        self.mpv = mpv

        let playableURL = media.url
        isRemoteSource = !playableURL.isFileURL

        // 与主播放器一致的软渲染管线；静音并关闭字幕，避免 headless 实例出声/烧字幕。
        mpv.setProperty(.vo, "libmpv")
        mpv.setProperty(.hwdec, Preferences.shared.hwdecEnabled ? "videotoolbox" : "no")
        mpv.audio.isMuted = true
        mpv.playback.isPaused = true
        mpv.subtitle.autoLoad = .no
        mpv.subtitle.assOverride = .no
        // 不烧字幕/不解码音频：动图只需要画面。
        mpv.setProperty(MPV.Property<String>("sid"), "no")
        mpv.setProperty(MPV.Property<String>("aid"), "no")

        let headerValue = file.httpHeaders
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\r\n")
        if !headerValue.isEmpty {
            mpv.setProperty(MPV.Property<String>("http-header-fields"), headerValue)
        }

        guard let handle = mpv.mpv else {
            finish(.failure(CaptureError.createFailed))
            return
        }

        renderer.outputScale = 1.0
        renderer.positionProvider = { [weak self] in self?.mpv?.time.position ?? 0 }
        renderer.videoSizeProvider = { [weak self] in self?.mpv?.videoSize ?? .zero }
        renderer.onFrame = { [weak self] sampleBuffer in
            guard let self = self else { return }
            self.queue.async {
                self.handleFrame(sampleBuffer)
            }
        }

        guard renderer.create(mpvHandle: handle) else {
            ANX.logError(.player, "[GIF][MPV] 创建渲染上下文失败")
            finish(.failure(CaptureError.createFailed))
            return
        }

        guard mpv.initialize() >= 0 else {
            ANX.logError(.player, "[GIF][MPV] mpv_initialize 失败")
            finish(.failure(CaptureError.createFailed))
            return
        }

        mpv.on(.fileLoaded) { [weak self] _ in
            guard let self = self else { return }
            self.queue.async { self.handleFileLoaded() }
        }

        mpv.on(.seek) { [weak self] _ in
            guard let self = self else { return }
            self.queue.async { self.handleSeekCompleted() }
        }

        mpv.on(.endFile) { [weak self] event in
            guard let self = self else { return }
            if case .endFile(let reason, let error, _, _, _) = event.data,
               reason != .eof || error < 0 {
                self.queue.async {
                    ANX.logError(.player, "[GIF][MPV] 播放结束: reason=\(reason), error=\(error)")
                    if !self.isFinished {
                        self.finish(.failure(CaptureError.loadFailed))
                    }
                }
            }
        }

        startLoadTimeout()
        ANX.logInfo(.player, "[GIF][MPV] 加载媒体: \(playableURL.absoluteString)")
        mpv.loadFile(playableURL.absoluteString)
    }

    private func startLoadTimeout() {
        loadTimeoutItem?.cancel()
        let timeout = isRemoteSource ? remoteLoadTimeout : localLoadTimeout
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isFinished, !self.isLoaded else { return }
            ANX.logError(.player, "[GIF][MPV] 加载超时")
            self.finish(.failure(CaptureError.loadTimedOut))
        }
        loadTimeoutItem = item
        queue.asyncAfter(deadline: .now() + timeout, execute: item)
    }

    private func handleFileLoaded() {
        guard !isFinished else { return }
        isLoaded = true
        loadTimeoutItem?.cancel()
        loadTimeoutItem = nil

        guard let mpv = mpv else {
            finish(.failure(CaptureError.loadFailed))
            return
        }

        let videoSize = mpv.videoSize
        if videoSize.width > 0, videoSize.height > 0 {
            // 渲染阶段直接按目标宽度缩放，避免 4K 帧全部留在内存里。
            if videoSize.width > maximumPixelWidth {
                renderer.outputScale = maximumPixelWidth / videoSize.width
            }
            ANX.logInfo(.player, "[GIF][MPV] 媒体已加载，尺寸 \(Int(videoSize.width))x\(Int(videoSize.height))")
        } else if videoSizeWaitCount < 20 {
            // 个别容器在 fileLoaded 时还没给出 video-params；短暂轮询，避免
            // renderer 因拿不到尺寸而一直不产出帧。
            videoSizeWaitCount += 1
            queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.handleFileLoaded()
            }
            return
        } else {
            // 仍未拿到尺寸：继续走 renderer，它会在首帧时再读取一次。
            ANX.logInfo(.player, "[GIF][MPV] 媒体已加载，尺寸待定")
        }

        mpv.playback.isPaused = true
        renderer.startRendering()
        captureNextFrame()
    }

    // MARK: - 抓帧

    private func captureNextFrame() {
        guard !isFinished else { return }
        guard let session = session, !session.isCancelled else {
            finish(.failure(CaptureError.cancelled))
            return
        }
        guard currentIndex < frameTimes.count else {
            finish(.success(frames))
            return
        }
        guard let mpv = mpv else {
            finish(.failure(CaptureError.loadFailed))
            return
        }

        let target = frameTimes[currentIndex]
        currentTarget = target
        isSeekCompleted = false
        frameRenderRetries = 0

        progress?(Double(currentIndex) / Double(frameTimes.count))
        startFrameTimeout()

        // 每帧都 seek，避免暂停位置漂移导致时间不准；位置已经一致时直接渲染，
        // 某些 mpv 版本对 no-op seek 不保证发出 seek 事件。
        mpv.playback.isPaused = true
        let currentPosition = mpv.time.position ?? 0
        if abs(currentPosition - target) <= 0.02 {
            queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self, !self.isFinished, self.currentTarget == target else { return }
                self.isSeekCompleted = true
                self.renderer.requestFrame()
            }
        } else {
            mpv.execute(.seek, args: [String(target), "absolute+exact"])
        }
    }

    private func handleSeekCompleted() {
        guard !isFinished, currentTarget != nil else { return }

        // seek 事件到达后画面可能还没稳定：延迟结束“seek 中”状态再主动渲染一帧，
        // 这样 seek 事件前残留的旧帧会被丢弃。
        queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, !self.isFinished, self.currentTarget != nil else { return }
            self.isSeekCompleted = true
            self.renderer.requestFrame()
        }
    }

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        guard !isFinished, isSeekCompleted, let target = currentTarget else { return }

        guard let position = mpv?.time.position,
              abs(position - target) <= 0.15 else {
            retryFrameRenderIfNeeded()
            return
        }

        guard let image = Self.makeImage(from: sampleBuffer, maximumPixelWidth: maximumPixelWidth) else {
            retryFrameRenderIfNeeded()
            return
        }

        frameTimeoutItem?.cancel()
        frameTimeoutItem = nil
        currentTarget = nil
        isSeekCompleted = false
        frames.append(image)
        currentIndex += 1
        progress?(Double(currentIndex) / Double(frameTimes.count))
        ANX.logInfo(.player, "[GIF][MPV] 已截取第 \(currentIndex)/\(frameTimes.count) 帧")
        captureNextFrame()
    }

    private func retryFrameRenderIfNeeded() {
        guard !isFinished else { return }
        frameRenderRetries += 1
        guard frameRenderRetries <= 5 else {
            finish(.failure(CaptureError.frameUnavailable))
            return
        }

        queue.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self = self, !self.isFinished, self.isSeekCompleted else { return }
            self.renderer.requestFrame()
        }
    }

    private func startFrameTimeout() {
        frameTimeoutItem?.cancel()
        let timeout = isRemoteSource ? remoteFrameTimeout : localFrameTimeout
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isFinished else { return }
            ANX.logError(.player, "[GIF][MPV] 抓帧超时")
            self.finish(.failure(CaptureError.frameTimedOut))
        }
        frameTimeoutItem = item
        queue.asyncAfter(deadline: .now() + timeout, execute: item)
    }

    // MARK: - 终止

    private func abort() {
        queue.async { [weak self] in
            guard let self = self, !self.isFinished else { return }
            self.finish(.failure(CaptureError.cancelled))
        }
    }

    private func finish(_ result: Result<[CGImage], Error>) {
        guard !isFinished else { return }
        isFinished = true
        loadTimeoutItem?.cancel()
        loadTimeoutItem = nil
        frameTimeoutItem?.cancel()
        frameTimeoutItem = nil
        session?.clearCancelHandler()
        session = nil
        currentTarget = nil

        self.result = result
        frames.removeAll()

        // 先释放渲染上下文，再关闭 mpv。
        renderer.onFrame = nil
        renderer.terminate()
        mpv?.quit()
        mpv = nil
        media = nil

        semaphore.signal()
    }

    // MARK: - 帧转换

    private static func makeImage(from sampleBuffer: CMSampleBuffer, maximumPixelWidth: CGFloat) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0,
              let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        // 渲染输出为 BGRA（源自 mpv 的 bgr0），用 noneSkipFirst 忽略 alpha。
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ), let image = context.makeImage() else {
            return nil
        }

        return downscale(image, maximumPixelWidth: maximumPixelWidth)
    }

    private static func downscale(_ image: CGImage, maximumPixelWidth: CGFloat) -> CGImage {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return image }

        let scale = min(1, maximumPixelWidth / CGFloat(width))
        guard scale < 0.999 else { return image }

        let targetWidth = max(1, Int((CGFloat(width) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(height) * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage() ?? image
    }
}
