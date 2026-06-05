//
//  MPVPiPProvider.swift
//  CocoaShare
//
//  headless mpv 播放器，vo=libmpv + SW render context，专用于 PiP 帧捕获
//

import Foundation
import AVFoundation
#if !os(tvOS)
import ANXLog
#endif
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
    private let renderer = MPVFrameRenderer()
    private var frameCaptureCount = 0
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

        guard let handle = mpv.mpv else {
            ANX.logError(.player, "[MPVPiP] mpv handle 为 nil")
            return nil
        }

        // 设置渲染器
        renderer.outputScale = 0.5
        renderer.positionProvider = { [weak self] in self?.mpv?.time.position ?? 0 }
        renderer.videoSizeProvider = { [weak self] in self?.mpv?.videoSize ?? .zero }
        renderer.onFrame = { [weak self] sampleBuffer in
            guard let self = self else { return }
            let isFirstFrame = self.frameCaptureCount == 0
            self.delegate?.pipPlayer(self, didOutputFrame: sampleBuffer)
            self.delegate?.pipPlayer(self, didChangePosition: self.currentPosition)
            if isFirstFrame, self.pauseAfterFirstFrame {
                self.pauseAfterFirstFrame = false
                self.pause()
            }
            self.frameCaptureCount += 1
        }
        renderer.onVideoSizeChange = { [weak self] size in
            guard let self = self else { return }
            self.delegate?.pipPlayer(self, didChangeVideoSize: size)
        }

        guard renderer.create(mpvHandle: handle) else {
            ANX.logError(.player, "[MPVPiP] 创建 MPVFrameRenderer 失败")
            return nil
        }

        let ret = mpv.initialize()
        guard ret >= 0 else {
            ANX.logError(.player, "[MPVPiP] mpv_initialize 失败: \(ret)")
            return nil
        }

        // 初始化后应用配置
        applyPostInitConfig(mpv: mpv, config: config)

        ANX.logInfo(.player, "[MPVPiP] 初始化完成")
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
                self.applyTrackConfig(to: mpv)
                mpv.time.seek(to: startPosition)
                // 始终先播放，让解码器产出首帧；如需暂停，首帧入队后再 pause
                mpv.playback.isPaused = false
                self.isPlaying = true
                self.pauseAfterFirstFrame = startPaused
                self.frameCaptureCount = 0
                self.renderer.startRendering()
                self.delegate?.pipPlayer(self, didChangePlayPause: true)
            }
        }

        mpv.loadFile(urlString)
    }

    func play() {
        guard let mpv = mpv else { return }
        mpv.playback.isPaused = false
        isPlaying = true
    }

    func pause() {
        guard let mpv = mpv else { return }
        mpv.playback.isPaused = true
        isPlaying = false
    }

    func seek(to position: Double) {
        guard let mpv = mpv else { return }
        mpv.time.seek(to: position)
    }

    func terminate() {
        ANX.logInfo(.player, "[MPVPiP] 终止")
        renderer.terminate()
        mpv?.quit()
        mpv = nil
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
            }
        }

        mpv.on(.endFile) { [weak self] event in
            if case .endFile(let reason, _, _, _, _) = event.data, reason == .eof {
                ANX.logInfo(.player, "[MPVPiP] 播放结束")
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.delegate?.pipPlayerDidEndFile(self)
                }
            }
        }
    }

}
