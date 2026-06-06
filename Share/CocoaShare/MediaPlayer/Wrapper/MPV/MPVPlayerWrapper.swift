//
//  MPVPlayerWrapper.swift
//  AniXPlayer
//
//  MPV 播放器封装，实现 MediaPlayerProtocol 接口
//  使用类型安全的 MPV API
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif
import AVFoundation
import MPVFramework
#if !os(tvOS)
import ANXLog
#endif

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

    private var lastTimeNotifyTime: TimeInterval = 0

    // MARK: - 渲染

    private let renderer = MPVFrameRenderer()
    private var didOutputFirstFrame = false

    // MARK: - 媒体视图
    
    private lazy var _mediaView = MPVView(frame: .zero)

    var mediaView: ANXView {
        return _mediaView
    }

    // MARK: - 协议属性

    var currentPlayItem: File? {
        didSet {
            if let item = currentPlayItem,
                let media = item.createMPVMedia() {
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
            let scaleFactor = _mediaView.screenScale
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
        renderer.requestFrame()
    }

    func pause() {
        ANX.logInfo(.player, "[MPV] 暂停")
        mpv?.playback.isPaused = true
    }

    func stop() {
        ANX.logInfo(.player, "[MPV] 停止")
        _mediaView.flush()
        renderer.startRendering()
        mpv?.stop()
        SMBFileManager.shared.stopStreaming()
        stateChangedCallBack?(self, .stop)
    }

    func terminate() {
        ANX.logInfo(.player, "[MPV] 终止")
        renderer.terminate()
        self.mpv?.quit()
        SMBFileManager.shared.stopStreaming()
        stateChangedCallBack?(self, .stop)
    }

    // MARK: - 初始化

    private func initializeMpv() {
        guard let mpvHandle = MPV() else {
            ANX.logError(.player, "[MPV] 创建失败")
            return
        }
        self.mpv = mpvHandle

        // vo=libmpv + SW render context: 渲染到内存 buffer，不依赖 CAMetalLayer swapchain
        mpvHandle.setOptionString(.vo, "libmpv")
        mpvHandle.setOptionString(.hwdec, "videotoolbox")

        // tvOS: 兼容杜比全景声（系统设置中开启全景声时默认 coreaudio 输出）
#if os(tvOS)
        mpvHandle.setOptionString(.audioSpdif, "no")
        mpvHandle.setOptionString(.audioChannels, "2")
#endif

        // 字幕配置
        setupSubtitleFonts(mpvHandle: mpvHandle)
        mpvHandle.subtitle.autoLoad = .no
        mpvHandle.subtitle.assOverride = .yes

        // MPVFrameRenderer 必须在 mpv_initialize 前创建（内部创建 MPVRenderContext）
        if let handle = mpvHandle.mpv {
            renderer.outputScale = 1.0
            renderer.positionProvider = { [weak self] in self?.mpv?.time.position ?? 0 }
            renderer.videoSizeProvider = { [weak self] in self?.mpv?.videoSize ?? .zero }
            renderer.onFrame = { [weak self] sampleBuffer in
                self?._mediaView.enqueue(sampleBuffer)
            }
            if !renderer.create(mpvHandle: handle) {
                ANX.logError(.player, "[MPV] MPVFrameRenderer 创建失败")
            }
        }

        let initRet = mpvHandle.initialize()
        ANX.logInfo(.player, "[MPV] mpv_initialize() 返回值: \(initRet)")

        // onReady 在首帧渲染后触发
        _mediaView.onReady = { [weak self] in
            guard let self = self else { return }
            self.didOutputFirstFrame = true
        }

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

        // 观察 time-pos 变化，节流到 0.5 秒通知 UI
        mpv.observe(.timePos) { [weak self] _ in
            let now = CACurrentMediaTime()
            guard let self = self, now - self.lastTimeNotifyTime >= 0.5 else { return }
            self.lastTimeNotifyTime = now
            DispatchQueue.main.async {
                self.timeChangedCallBack?(self, self.position)
            }
        }

        // 文件播放结束（获取具体原因）
        mpv.on(.endFile) { [weak self] event in
            if case .endFile(let reason, let error, _, _, _) = event.data {
                ANX.logInfo(.player, "[MPV] 文件结束: reason=\(reason), error=\(error)")
                DispatchQueue.main.async {
                    guard let self = self, reason == .eof else { return }
                    self.endOfFileCallBack?(self)
                }
            }
        }

        // 文件加载完成
        mpv.on(.fileLoaded) { [weak self] _ in
            ANX.logInfo(.player, "[MPV] 文件加载完成")
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.renderer.startRendering()
                self.updateTrackLists()
                self.renderer.requestFrame()
            }
        }

        // 关机事件
        mpv.on(.shutdown) { [weak self] _ in
            ANX.logInfo(.player, "[MPV] 关机")
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.renderer.terminate()
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

    // MARK: - 播放时间通知（通过 mpv time-pos 属性观察，节流到 0.5 秒）

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
        renderer.terminate()
    }
}

// MARK: - MPVView

class MPVView: ANXView {

    private lazy var displayLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        return layer
    }()

    /// 首次收到帧时的回调，用于通知播放器渲染已就绪
    var onReady: (() -> Void)?
    private var didFireReady = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

#if os(iOS) || os(tvOS)
    override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer.frame = bounds
    }
#else
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        CATransaction.commit()
    }
#endif

    private var enqueueCount = 0
    private var dropCount = 0

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        if displayLayer.status == .failed {
            ANX.logError(.player, "[MPVView] displayLayer 进入失败状态: \(displayLayer.error?.localizedDescription ?? "nil")")
            displayLayer.flush()
        }
        if displayLayer.isReadyForMoreMediaData {
            displayLayer.enqueue(sampleBuffer)
            enqueueCount += 1
            if displayLayer.status == .failed {
                ANX.logError(.player, "[MPVView] enqueue 后 displayLayer 失败: \(displayLayer.error?.localizedDescription ?? "nil")")
            }
        } else {
            dropCount += 1
            if dropCount <= 3 || dropCount % 30 == 0 {
                ANX.logInfo(.player, "[MPVView] displayLayer 未就绪，丢弃帧 (共丢弃 \(dropCount) 帧)")
            }
        }
        if !didFireReady {
            didFireReady = true
            ANX.logInfo(.player, "[MPVView] 首帧到达 (enqueueCount=\(enqueueCount), dropCount=\(dropCount))")
            onReady?()
            onReady = nil
        }
    }

    func flush() {
        displayLayer.flush()
    }

    private func setup() {
#if os(macOS)
        wantsLayer = true
        layer?.backgroundColor = ANXColor.black.cgColor
        layer?.addSublayer(displayLayer)
#else
        backgroundColor = ANXColor.black
        layer.addSublayer(displayLayer)
#endif
    }

    var screenScale: CGFloat {
#if os(iOS) || os(tvOS)
        return UIScreen.main.scale
#else
        return NSScreen.main?.backingScaleFactor ?? 2.0
#endif
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
