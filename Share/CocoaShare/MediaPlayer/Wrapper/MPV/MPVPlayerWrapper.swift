//
//  MPVPlayerWrapper.swift
//  AniXPlayer
//
//  MPV 播放器封装，实现 MediaPlayerProtocol 接口
//  使用类型安全的 MPV API
//

#if os(iOS) || os(tvOS)

import Foundation
import UIKit
import Metal
import QuartzCore
import AVFoundation
import MPVFramework
import ANXLog

// MARK: - 内嵌字幕
struct MPVSubtitle: SubtitleProtocol {
    let subtitleName: String
    let trackId: Int64
}

struct MPVAudioChannel: AudioChannelProtocol {
    let audioName: String
    let audioId: Int64
}

// MARK: - MPVPlayerWrapper

class MPVPlayerWrapper: NSObject, MediaPlayerProtocol {

    // MARK: - 私有属性

    private lazy var mpv = MPV()

    private let eventQueue = DispatchQueue(label: "com.anxplayer.mpvwrapper", qos: .userInitiated)

    /// 播放轮询定时器
    private var playbackTimer: Timer?

    // MARK: - 媒体视图
    
    private lazy var _mediaView = MPVView(frame: .zero)

    /// windowId 是否已配置到 mpv（CAMetalLayer 尺寸就绪）
    private var windowIdConfigured = false

    var mediaView: ANXView {
        return _mediaView
    }

    // MARK: - 协议属性

    var currentPlayItem: File? {
        didSet {
            if let item = currentPlayItem,
                let media = item.createMPVMedia() {
                configureWindowIdIfNeeded()
                mpv?.loadFile(media.url.absoluteString)
            }
        }
    }

    var subtitleList: [SubtitleProtocol] {
        return _subtitleList
    }
    private lazy var _subtitleList = [MPVSubtitle]()

    /// 当前字幕轨道 ID（nil = 无字幕）
    var currentSubtitleTrackId: Int64? {
        return mpv?.subtitle.subtitleId
    }

    var currentSubtitle: SubtitleProtocol? {
        get {
            if let id = self.mpv?.subtitle.subtitleId {
                return self._subtitleList.first { sub in
                    return sub.trackId == id
                }
            }
            return nil
        }
        set {
            if let sub = newValue as? MPVSubtitle {
                ANX.logInfo(.player, "[MPV] 选择字幕: \(sub.subtitleName) (id: \(sub.trackId))")
                self.mpv?.subtitle.subtitleId = Int64(sub.trackId)
            } else if let sub = newValue as? ExternalSubtitle {
                ANX.logInfo(.player, "[MPV] 添加外部字幕: \(sub.url.lastPathComponent)")
                self.mpv?.subtitle.addExternal(path: sub.url.path)
            } else {
                ANX.logInfo(.player, "[MPV] 关闭字幕")
                self.mpv?.subtitle.subtitleId = 0
            }
        }
    }

    var audioChannelList: [AudioChannelProtocol] {
        return _audioChannelList
    }
    private lazy var _audioChannelList = [MPVAudioChannel]()

    var currentAudioChannel: AudioChannelProtocol? {
        get {
            if let id = self.mpv?.audio.audioId {
                return self._audioChannelList.first { audio in
                    return audio.audioId == id
                }
            }
            return nil
        }
        set {
            if let audio = newValue {
                ANX.logInfo(.player, "[MPV] 选择音轨: \(audio.audioName) (id: \(audio.audioId))")
            }
            self.mpv?.audio.audioId = newValue?.audioId
        }
    }

    var timeChangedCallBack: ((MediaPlayerProtocol, Double) -> Void)?
    var stateChangedCallBack: ((MediaPlayerProtocol, PlayerState) -> Void)?
    var bufferInfoDidChangeCallBack: ((MediaPlayerProtocol, File, MediaBufferInfo) -> Void)?
    var endOfFileCallBack: ((MediaPlayerProtocol) -> Void)?

    var volume: Int = 100 {
        didSet {
            ANX.logDebug(.player, "[MPV] 音量: \(oldValue) -> \(self.volume)")
            self.mpv?.audio.volume = Int64(self.volume)
        }
    }

    var subtitleOffsetTime: Double {
        get {
            // MPV sub-delay 负值表示延后，正值表示提前
            // 取反后：正值=延后，负值=提前，与 VLC 语义一致
            return -(self.mpv?.subtitle.delay ?? 0)
        }
        set {
            ANX.logDebug(.player, "[MPV] 字幕延迟: \(newValue)s")
            self.mpv?.subtitle.delay = -newValue
        }
    }

    var subtitleStyle: Bool {
        get {
            self.mpv?.subtitle.assOverride != .no
        }

        set {
            ANX.logDebug(.player, "[MPV] 字幕样式: \(newValue ? "强制" : "关闭")")
            self.mpv?.subtitle.assOverride = newValue ? .force : .no
        }
    }

    var audioOffsetTime: Double {
        get {
            // MPV audio-delay 负值表示延后，正值表示提前
            // 取反后：正值=延后，负值=提前，与 VLC 语义一致
            return -(self.mpv?.audio.delay ?? 0)
        }
        set {
            ANX.logDebug(.player, "[MPV] 音频延迟: \(newValue)s")
            self.mpv?.audio.delay = -newValue
        }
    }

    var speed: Double = 1.0 {
        didSet {
            ANX.logInfo(.player, "[MPV] 播放速度: \(self.speed)")
            self.mpv?.playback.setSpeed(self.speed)
        }
    }

    var aspectRatio: PlayerAspectRatio = .default {
        didSet {
            switch self.aspectRatio {
            case .default:
                self.mpv?.video.aspectRatio = 0
            case .fillToScreen:
                self.mpv?.video.aspectRatio = -1
            case .fourToThree:
                self.mpv?.video.aspectRatio = 4.0 / 3.0
            case .sixteenToNine:
                self.mpv?.video.aspectRatio = 16.0 / 9.0
            case .sixteenToTen:
                self.mpv?.video.aspectRatio = 16.0 / 10.0
            }
        }
    }

    var subtitleYPosition: Float = 0 {
        didSet {
            // 获取视图高度（考虑缩放比例）
            let scaleFactor: CGFloat
#if os(iOS) || os(tvOS)
            scaleFactor = self.mediaView.window?.screen.scale ?? UIScreen.main.scale
#else
            scaleFactor = self.mediaView.window?.backingScaleFactor ?? 1.0
#endif
            let screenHeight = Int64(self.mediaView.bounds.height * scaleFactor)

            // percent=0 时 margin 为 0（贴近底部）
            // percent=100 时 margin 为 screenHeight（贴近顶部）
            let percent = Int64(subtitleYPosition)
            let bottom = (screenHeight * percent) / 100

            // sub-margin-y: 对文本字幕有效
            self.mpv?.subtitle.marginY = bottom

            // sub-pos: 100=原始位置，<100往上移
            // percent=0 时贴近底部（原始位置），percent=100 时贴近顶部
            let posValue = 100 - percent
            self.mpv?.subtitle.position = posValue

            ANX.logDebug(.player, "[MPV] 字幕位置: \(percent)%")
        }
    }

    var position: Double {
        if self.length == 0 {
            return 0
        }
        return self.currentTime / self.length
    }

    var length: TimeInterval {
        if let durationValue = self.mpv?.time.duration, durationValue > 0 {
            return durationValue
        }
        
        return 0
    }

    var currentTime: TimeInterval {
        if let currentTimeValue = self.mpv?.time.position {
            return currentTimeValue
        }
        return 0
    }

    var state: PlayerState {
        guard let mpv = mpv else { return .stop }
        return mpv.playback.isPaused ? .pause : .playing
    }

    var isPlaying: Bool {
        return state == .playing
    }

    var fontSize: Float? {
        didSet {
            guard let size = self.fontSize else { return }
            ANX.logDebug(.player, "[MPV] 字体大小: \(size)")
            self.mpv?.subtitle.fontSize = Int64(size)
        }
    }

    var fontName: String? {
        didSet {
            // MPV 使用打包的思源黑体
        }
    }

    var fontColor: ANXColor? {
        didSet {
            ANX.logDebug(.player, "[MPV] 字体颜色已更改")
            self.mpv?.subtitle.color = self.fontColor
        }
    }
    
    override init() {
        super.init()
        initializeMpv()
    }

    // MARK: - 协议方法

    func setPosition(_ position: Double) {
        let pos = max(min(position, 1), 0)
        let time = pos * self.length
        ANX.logInfo(.player, "[MPV] 跳转: \(time)s (进度: \(pos))")
        mpv?.time.seek(to: time)
    }

    func play(_ media: File) {
        currentPlayItem = media
        play()
    }

    func play() {
        ANX.logInfo(.player, "[MPV] 播放")
        mpv?.playback.isPaused = false
        startPlaybackPolling()
    }

    func pause() {
        ANX.logInfo(.player, "[MPV] 暂停")
        mpv?.playback.isPaused = true
        stopPlaybackPolling()
    }

    func stop() {
        ANX.logInfo(.player, "[MPV] 停止")
        stopPlaybackPolling()
        mpv?.stop()
        SMBFileManager.shared.stopStreaming()
        stateChangedCallBack?(self, .stop)
    }

    func terminate() {
        ANX.logInfo(.player, "[MPV] 终止")
        stopPlaybackPolling()
        self.mpv?.quit()
        SMBFileManager.shared.stopStreaming()
        stateChangedCallBack?(self, .stop)
    }

    // MARK: - 初始化

    /// 确保 windowId 已配置（layoutSubviews 首次触发的 onReady 尚未回调时，作为 fallback）
    private func configureWindowIdIfNeeded() {
        guard !windowIdConfigured, let mpvHandle = mpv else { return }
        let metalLayerPtr = Unmanaged.passUnretained(_mediaView.metalLayer).toOpaque()
        mpvHandle.video.windowId = Int64(Int(bitPattern: metalLayerPtr))
        windowIdConfigured = true
    }

    private func initializeMpv() {
        guard let mpvHandle = MPV() else {
            ANX.logError(.player, "[MPV] 创建失败")
            return
        }
        self.mpv = mpvHandle

        // vo=gpu-next + hwdec=videotoolbox: GPU 路径，渲染到 CAMetalLayer 上屏
        // 主播放器走硬件加速以获得最佳性能/功耗，与 PiP (libmpv SW) 路线不同
        mpvHandle.setOptionString(.vo, "gpu-next")
        mpvHandle.setOptionString(.hwdec, "videotoolbox")
        // 延迟到 MPVView 首次布局完成后再配置渲染目标 (windowId)，
        // 避免 CAMetalLayer 尺寸为 1x1 时 mpv 就开始渲染导致 Metal validation 错误
        _mediaView.onReady = { [weak self, weak mpvHandle] in
            guard let self = self, let mpvHandle = mpvHandle else { return }
            let metalLayerPtr = Unmanaged.passUnretained(self._mediaView.metalLayer).toOpaque()
            mpvHandle.video.windowId = Int64(Int(bitPattern: metalLayerPtr))
            self.windowIdConfigured = true
        }

        // 字幕配置
        setupSubtitleFonts(mpvHandle: mpvHandle)
        mpvHandle.subtitle.autoLoad = .no
        mpvHandle.subtitle.assOverride = .yes

        let initRet = mpvHandle.initialize()
        ANX.logInfo(.player, "[MPV] mpv_initialize() 返回值: \(initRet)")

        setupEventHandlers(mpvHandle)
    }

    private func setupEventHandlers(_ mpv: MPV) {
        // 观察 track-list 变化
        mpv.observe(.trackList) { [weak self] _ in
            ANX.logDebug(.player, "[MPV] 轨道列表已更改")
            DispatchQueue.main.async {
                self?.updateTrackLists()
            }
        }

        // 观察 pause 变化
        mpv.observe(.pause) { [weak self] value in
            if case .flag(let isPaused) = value {
                ANX.logInfo(.player, "[MPV] 暂停状态: \(isPaused ? "是" : "否")")
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                let isPaused = self.mpv?.playback.isPaused ?? false
                self.stateChangedCallBack?(self, isPaused ? .pause : .playing)
            }
        }

        // 文件播放结束（获取具体原因）
        mpv.on(.endFile) { [weak self] event in
            if case .endFile(let reason, let error, _, _, _) = event.data {
                ANX.logInfo(.player, "[MPV] 文件结束: reason=\(reason), error=\(error)")
                DispatchQueue.main.async {
                    guard let self = self, reason == .eof else { return }
                    self.stopPlaybackPolling()
                    self.endOfFileCallBack?(self)
                }
            }
        }

        // 文件加载完成
        mpv.on(.fileLoaded) { [weak self] _ in
            ANX.logInfo(.player, "[MPV] 文件加载完成")
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateTrackLists()
            }
        }

        // 关机事件
        mpv.on(.shutdown) { [weak self] _ in
            ANX.logInfo(.player, "[MPV] 关机")
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.mpv?.video.windowId = 0
                self._mediaView.metalLayer.device = nil
                self.mpv?.stopEventLoop()
                self.mpv = nil
            }
        }
    }

    private func setupSubtitleFonts(mpvHandle: MPV) {
        guard let fontDir = mpvPrepareFonts() else { return }
        mpvHandle.setOptionString(.subtitleFontsDir, fontDir)
        mpvHandle.setOptionString(.subtitleFont, mpvCustomFontNames.first ?? "")
    }

    // MARK: - 播放轮询

    private func startPlaybackPolling() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.timeChangedCallBack?(self, self.position)
        }
    }

    private func stopPlaybackPolling() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - 轨道列表更新

    private func updateTrackLists() {
        guard let mpv = mpv else { return }

        _subtitleList = mpv.track.subtitleTracks.map { track in
            MPVSubtitle(subtitleName: track.displayName, trackId: track.id)
        }

        _audioChannelList = mpv.track.audioTracks.map { track in
            MPVAudioChannel(audioName: track.displayName, audioId: track.id)
        }
    }

    deinit {
        stopPlaybackPolling()
    }
}

// MARK: - MPVView

class MPVView: UIView {

    private(set) lazy var metalLayer = CAMetalLayer()

    /// 首次完成布局（bounds 非零）时的回调，用于通知播放器配置渲染目标
    var onReady: (() -> Void)?
    private var didLayoutOnce = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.metalLayer.frame = self.bounds
        if !didLayoutOnce, !bounds.isEmpty {
            didLayoutOnce = true
            onReady?()
            onReady = nil
        }
    }

    private func setup() {
        backgroundColor = .black

        metalLayer.device = MTLCreateSystemDefaultDevice()
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.backgroundColor = UIColor.black.cgColor
        metalLayer.contentsScale = UIScreen.main.scale
        metalLayer.frame = self.bounds

        self.layer.addSublayer(metalLayer)
    }
}

// MARK: - PiP 工厂

extension MPVPlayerWrapper {

    /// 创建一个 headless PiP 播放器实例，配置从主播放器同步
    func createPiPPlayer(with config: PiPPlayerConfig) -> PiPPlayerProtocol? {
        let cfg = config
        // PiP 必须用软件渲染（iOS 后台禁 GPU）
        cfg.extra["hwdec"] = "no"
        if cfg.subtitleFontsDir == nil {
            cfg.subtitleFontsDir = mpvPrepareFonts()
        }
        if cfg.subtitleFont == nil {
            cfg.subtitleFont = mpvCustomFontNames.first
        }
        return MPVPiPProvider(config: cfg)
    }
}
#endif
