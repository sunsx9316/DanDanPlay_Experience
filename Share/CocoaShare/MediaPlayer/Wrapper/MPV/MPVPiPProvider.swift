//
//  MPVPiPProvider.swift
//  CocoaShare
//
//  headless mpv 播放器，vo=libmpv + SW render context，专用于 PiP 帧捕获
//

import Foundation
import AVFoundation
import ANXLog
import MPVFramework

class MPVPiPProvider: PiPPlayerProtocol {

    // MARK: - PiPPlayerProtocol

    weak var delegate: PiPPlayerDelegate?

    var currentPosition: Double {
        mpv?.time.position ?? 0
    }

    var duration: Double {
        if let d = mpv?.time.duration, d > 0 { return d }
        return 0
    }

    private(set) var isPlaying = true

    // MARK: - 私有

    private var mpv: MPV?
    private var renderContext: MPVRenderContext?
    private var renderBuffer: UnsafeMutableRawPointer?
    private var renderBufferSize: Int = 0
    private var videoSize: CGSize = .zero
    private var captureTimer: Timer?
    private let captureQueue = DispatchQueue(label: "com.anixplayer.pip.capture", qos: .userInitiated)
    private var isCapturing = false
    private var frameCaptureCount = 0
    private var skipCount = 0
    private var pauseAfterFirstFrame = false
    var config: PiPPlayerConfig

    // MARK: - 初始化

    init?(config: PiPPlayerConfig) {
        self.config = config

        guard let mpv = MPV() else {
            ANX.logError(.player, "[MPVPiP] MPV 创建失败")
            return nil
        }
        self.mpv = mpv

        // vo=libmpv + hwdec=no: 纯 CPU 路径，渲染到内存 buffer 用于 PiP CMSampleBuffer 输出
        // iOS 后台不允许访问 GPU，必须用软件渲染确保 PiP 在后台正常播放
        mpv.setOptionString(.vo, "libmpv")
        mpv.setOptionString(.hwdec, (config.extra["hwdec"] as? String) ?? "no")
        setupSubtitleFonts(mpv: mpv, config: config)

        guard let handle = mpv.mpvHandle,
              let ctx = MPVRenderContext(mpvHandle: handle) else {
            ANX.logError(.player, "[MPVPiP] 创建 MPVRenderContext 失败")
            return nil
        }
        self.renderContext = ctx

        let ret = mpv.initialize()
        guard ret >= 0 else {
            ANX.logError(.player, "[MPVPiP] mpv_initialize 失败: \(ret)")
            return nil
        }

        // 初始化后应用配置
        applyPostInitConfig(mpv: mpv, config: config)

        ANX.logInfo(.player, "[MPVPiP] 初始化完成 (vo=libmpv + SW render context)")
        setupObservers()
    }

    // MARK: - 生命周期

    func loadAndPlay(urlString: String) {
        guard let mpv = mpv else { return }
        let startPosition = config.startPosition
        let startPaused = config.startPaused

        ANX.logInfo(.player, "[MPVPiP] 加载, start=\(String(format: "%.1f", startPosition))s, startPaused=\(startPaused)")

        mpv.on(.fileLoaded) { [weak self] _ in
            ANX.logInfo(.player, "[MPVPiP] 文件加载完成")
            DispatchQueue.main.async {
                guard let self = self, let mpv = self.mpv else { return }
                self.readVideoSize(from: mpv)
                self.applyTrackConfig(to: mpv)
                mpv.time.seek(to: startPosition)
                // 始终先播放，让解码器产出首帧；如需暂停，首帧入队后再 pause
                mpv.playback.isPaused = false
                self.isPlaying = true
                self.pauseAfterFirstFrame = startPaused
                self.startFrameCapture()
                self.delegate?.pipPlayer(self, didChangePlayPause: true)
            }
        }

        mpv.loadFile(urlString)
    }

    func play() {
        guard let mpv = mpv else { return }
        mpv.playback.isPaused = false
        isPlaying = true
        startFrameCapture()
    }

    func pause() {
        guard let mpv = mpv else { return }
        mpv.playback.isPaused = true
        isPlaying = false
        stopFrameCapture()
    }

    func seek(to position: Double) {
        guard let mpv = mpv else { return }
        mpv.time.seek(to: position)
    }

    func terminate() {
        ANX.logInfo(.player, "[MPVPiP] 终止")
        stopFrameCapture()
        mpv?.quit()
        mpv = nil
        renderBuffer?.deallocate()
        renderBuffer = nil
        renderContext = nil
        isPlaying = false
    }

    func applyConfig(_ config: PiPPlayerConfig) {
        self.config = config
        guard let mpv = mpv else { return }
        applyPostInitConfig(mpv: mpv, config: config)
        applyTrackConfig(to: mpv)
    }

    // MARK: - 配置应用

    private func applyPostInitConfig(mpv: MPV, config: PiPPlayerConfig) {
        mpv.playback.setSpeed(config.speed)
        mpv.subtitle.assOverride = config.subtitleOverride ? .force : .no
        mpv.subtitle.delay = -config.subtitleDelay

        if let size = config.subtitleFontSize {
            mpv.subtitle.fontSize = Int64(size)
        }

        if let color = config.subtitleColor {
            mpv.subtitle.color = color
        }

        if let yPos = config.subtitleYPosition {
            let percent = Int64(yPos)
            mpv.subtitle.marginY = percent
            mpv.subtitle.position = 100 - percent
        }

        mpv.audio.volume = Int64(config.volume)
    }

    // MARK: - 字体配置

    /// 应用字幕 / 音频轨道选择
    private func applyTrackConfig(to mpv: MPV) {
        if let sub = config.currentSubtitle {
            if let ext = sub as? ExternalSubtitle {
                mpv.subtitle.addExternal(path: ext.url.path)
            } else if let mpvSub = sub as? MPVSubtitle {
                mpv.subtitle.subtitleId = Int64(mpvSub.trackId)
            }
        }
        if let audio = config.currentAudioChannel as? MPVAudioChannel {
            mpv.audio.audioId = Int64(audio.audioId)
        }
    }

    private func setupSubtitleFonts(mpv: MPV, config: PiPPlayerConfig) {
        guard let fontDir = mpvPrepareFonts() else { return }
        mpv.setOptionString(.subtitleFontsDir, fontDir)
        mpv.setOptionString(.subtitleFont, config.subtitleFont ?? mpvCustomFontNames.first ?? "")
    }

    // MARK: - 事件监听

    private func setupObservers() {
        guard let mpv = mpv else { return }

        mpv.observe(.pause) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let paused = self.mpv?.playback.isPaused ?? true
                self.isPlaying = !paused
                self.delegate?.pipPlayer(self, didChangePlayPause: !paused)
                if paused {
                    self.stopFrameCapture()
                } else {
                    self.startFrameCapture()
                }
            }
        }

        mpv.on(.endFile) { [weak self] event in
            if case .endFile(let reason, _, _, _, _) = event.data, reason == .eof {
                ANX.logInfo(.player, "[MPVPiP] 播放结束")
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.stopFrameCapture()
                    self.delegate?.pipPlayerDidEndFile(self)
                }
            }
        }

        mpv.on(.videoReconfig) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let mpv = self.mpv else { return }
                self.readVideoSize(from: mpv)
            }
        }
    }

    private func readVideoSize(from mpv: MPV) {
        let size = mpv.videoSize
        if size != .zero, size != videoSize {
            videoSize = size
            ANX.logInfo(.player, "[MPVPiP] 视频尺寸: \(Int(size.width))x\(Int(size.height))")
        }
    }

    // MARK: - 帧捕获

    private func startFrameCapture() {
        stopFrameCapture()
        frameCaptureCount = 0
        skipCount = 0
        captureTimer = Timer.scheduledTimer(withTimeInterval: pipCaptureInterval, repeats: true) { [weak self] _ in
            self?.captureAndDeliverFrame()
        }
    }

    private func stopFrameCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
    }

    private func captureAndDeliverFrame() {
        guard !isCapturing else {
            skipCount += 1
            return
        }
        isCapturing = true

        captureQueue.async { [weak self] in
            guard let self = self,
                  let mpv = self.mpv,
                  let ctx = self.renderContext else { return }

            // 每次渲染前尝试读尺寸
            if self.videoSize == .zero {
                let size = mpv.videoSize
                if size != .zero {
                    self.videoSize = size
                    ANX.logInfo(.player, "[MPVPiP] 视频尺寸就绪: \(Int(size.width))x\(Int(size.height))")
                }
            }

            let srcSize = self.videoSize

            // 尺寸未知时用安全默认值
            let pipWidth: Int
            let pipHeight: Int
            if srcSize.width > 0, srcSize.height > 0 {
                pipWidth = max(Int(srcSize.width) / 2, 1)
                pipHeight = max(Int(srcSize.height) / 2, 1)
            } else {
                pipWidth = pipFallbackWidth
                pipHeight = pipFallbackHeight
            }

            let pipStride = pipWidth * 4
            let alignedStride = ((pipStride + pipBufferAlignment - 1) / pipBufferAlignment) * pipBufferAlignment
            let neededSize = alignedStride * pipHeight
            if neededSize != self.renderBufferSize {
                self.renderBuffer?.deallocate()
                self.renderBuffer = UnsafeMutableRawPointer.allocate(byteCount: neededSize, alignment: pipBufferAlignment)
                self.renderBufferSize = neededSize
            }

            // Step 1: mpv render
            guard let buffer = self.renderBuffer,
                  ctx.render(to: buffer,
                             width: pipWidth, height: pipHeight,
                             stride: alignedStride,
                             format: "bgr0",
                             blockForTarget: false) else {
                self.isCapturing = false
                return
            }

            let pos = self.mpv?.time.position ?? 0

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.pipPlayer(self, didChangePosition: pos)
            }

            if self.frameCaptureCount == 0 {
                ANX.logInfo(.player, "[MPVPiP] 首帧: PiP\(pipWidth)x\(pipHeight), pos=\(String(format: "%.2f", pos))")
                if srcSize.width > 0 {
                    DispatchQueue.main.async {
                        self.delegate?.pipPlayer(self, didChangeVideoSize: srcSize)
                    }
                }
            }

            // Step 2: CVPixelBuffer
            let pixelBufferAttrs: [CFString: Any] = [
                kCVPixelBufferIOSurfacePropertiesKey: [:],
            ]
            var pixelBuffer: CVPixelBuffer?
            let cvRet = CVPixelBufferCreate(
                nil, pipWidth, pipHeight,
                kCVPixelFormatType_32BGRA,
                pixelBufferAttrs as CFDictionary,
                &pixelBuffer
            )
            guard cvRet == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
                ANX.logError(.player, "[MPVPiP] CVPixelBufferCreate 失败: \(cvRet)")
                self.isCapturing = false
                return
            }

            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

            guard let dstBaseAddr = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                self.isCapturing = false
                return
            }
            let dstStride = CVPixelBufferGetBytesPerRow(pixelBuffer)

            // Step 3: memcpy
            let srcPtr = buffer.assumingMemoryBound(to: UInt8.self)
            let dstPtr = dstBaseAddr.assumingMemoryBound(to: UInt8.self)
            let copyBytes = pipWidth * 4
            for y in 0..<pipHeight {
                let srcRow = srcPtr.advanced(by: y * alignedStride)
                let dstRow = dstPtr.advanced(by: y * dstStride)
                dstRow.update(from: srcRow, count: copyBytes)
            }

            // Step 4: CMSampleBuffer
            var sampleBuffer: CMSampleBuffer?
            var formatDesc: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDesc)
            guard let formatDesc = formatDesc else {
                self.isCapturing = false
                return
            }

            let pts = CMTime(seconds: pos, preferredTimescale: pipTimescale)
            var timing = CMSampleTimingInfo(
                duration: .invalid,
                presentationTimeStamp: pts,
                decodeTimeStamp: .invalid
            )

            CMSampleBufferCreateReadyWithImageBuffer(
                allocator: nil,
                imageBuffer: pixelBuffer,
                formatDescription: formatDesc,
                sampleTiming: &timing,
                sampleBufferOut: &sampleBuffer
            )
            guard let sampleBuffer = sampleBuffer else {
                self.isCapturing = false
                return
            }

            let isFirstFrame = self.frameCaptureCount == 0

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.pipPlayer(self, didOutputFrame: sampleBuffer)
                if isFirstFrame, self.pauseAfterFirstFrame {
                    self.pauseAfterFirstFrame = false
                    self.pause()
                }
            }

            self.frameCaptureCount += 1
            self.isCapturing = false
        }
    }
}
