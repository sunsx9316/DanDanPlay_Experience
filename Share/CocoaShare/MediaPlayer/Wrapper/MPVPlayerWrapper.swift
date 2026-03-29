//
//  MPVPlayerWrapper.swift
//  AniXPlayer
//
//  MPV 播放器封装，实现 MediaPlayerProtocol 接口
//  使用类型安全的 MPV API
//

#if os(iOS)

import Foundation
import MPVFramework

// MARK: - 内嵌字幕
private struct Subtitle: SubtitleProtocol {
    let subtitleName: String
    let index: Int
    let trackId: Int
}

// MARK: - MPVPlayerWrapper

class MPVPlayerWrapper: NSObject, MediaPlayerProtocol {

    // MARK: - 私有属性

    private var mpv: MPV?
    private let eventQueue = DispatchQueue(label: "com.anxplayer.mpvwrapper", qos: .userInitiated)

    /// 渲染视图
    private var renderView: MPVView?

    /// 当前选择的字幕文件
    private var currentSubTitleFile: SubtitleProtocol?

    /// 字幕轨道列表
    private var subtitleTracks: [SubtitleProtocol] = []

    /// 音频轨道列表
    private var audioTracks: [AudioChannelProtocol] = []

    /// 是否已初始化
    private var isInitialized = false

    /// 播放时长
    private var duration: TimeInterval = 0

    /// 当前播放位置
    private var currentPosition: Double = 0

    /// 初始化操作队列
    private var initActions: [() -> Void] = []

    /// 播放轮询定时器
    private var playbackTimer: Timer?

    /// 结束位置阈值
    private let endFlagProgress = 0.99

    // MARK: - 媒体视图

    var mediaView: ANXView {
        if renderView == nil {
            renderView = MPVView(frame: .zero)
        }
        return renderView!
    }

    // MARK: - 协议属性

    var currentPlayItem: File? {
        didSet {
            if !isInitialized {
                setupMpv()
                for action in initActions {
                    action()
                }
                
                isInitialized = true
            }

            if let item = currentPlayItem {
                mpv?.loadFile(item.url.path)
            }
        }
    }

    var subtitleList: [SubtitleProtocol] {
        return subtitleTracks
    }

    var currentSubtitle: SubtitleProtocol? {
        get {
            return currentSubTitleFile
        }
        set {
            currentSubTitleFile = newValue

            let setup = { [weak self] in
                guard let self = self else { return }
                if let sub = newValue as? Subtitle {
                    self.mpv?.subtitle.subtitleId = Int64(sub.trackId)
                } else if let sub = newValue as? ExternalSubtitle {
                    self.mpv?.subtitle.addExternal(path: sub.url.path)
                } else {
                    self.mpv?.subtitle.subtitleId = 0
                }
            }

            if isInitialized {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var audioChannelList: [AudioChannelProtocol] {
        return audioTracks
    }

    var currentAudioChannel: AudioChannelProtocol? {
        didSet {
            let setup = { [weak self] in
                guard let self = self else { return }
                if let channel = self.currentAudioChannel {
                    self.mpv?.audio.audioId = Int64(channel.audioId)
                }
            }

            if isInitialized {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var timeChangedCallBack: ((MediaPlayerProtocol, Double) -> Void)?
    var stateChangedCallBack: ((MediaPlayerProtocol, PlayerState) -> Void)?
    var bufferInfoDidChangeCallBack: ((MediaPlayerProtocol, File, MediaBufferInfo) -> Void)?

    var volume: Int = 100 {
        didSet {
            let setup = { [weak self] in
                guard let self = self else { return }
                self.mpv?.audio.volume = Int64(self.volume)
            }

            if isInitialized {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var subtitleOffsetTime: Double = 0

    var audioOffsetTime: Double = 0

    var speed: Double = 1.0 {
        didSet {
            let setup = { [weak self] in
                guard let self = self else { return }
                self.mpv?.playback.setSpeed(self.speed)
            }

            if isInitialized {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var aspectRatio: PlayerAspectRatio = .default {
        didSet {
            let setup = { [weak self] in
                guard let self = self else { return }
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

            if isInitialized {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var subtitleMargin: Int = 0

    var position: Double {
        guard duration > 0 else { return 0 }
        return currentPosition
    }

    var length: TimeInterval {
        return duration
    }

    var currentTime: TimeInterval {
        return currentPosition * duration
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
            let setup = { [weak self] in
                guard let self = self else { return }
                self.mpv?.subtitle.fontSize = Int64(size)
            }

            if isInitialized {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var fontName: String? {
        didSet {
            // MPV 使用打包的思源黑体
        }
    }

    var fontColor: ANXColor? {
        didSet {
            guard let color = self.fontColor else { return }
            let setup = { [weak self] in
                guard let self = self else { return }
                self.mpv?.subtitle.color = color
            }

            if isInitialized {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    // MARK: - 协议方法

    func setPosition(_ position: Double) {
        let pos = max(min(position, 1), 0)
        currentPosition = pos
        let time = pos * duration
        mpv?.time.seek(to: time)
    }

    func play(_ media: File) {
        currentPlayItem = media
        play()
    }

    func play() {
        guard let mpv = mpv else { return }
        mpv.playback.isPaused = false
        startPlaybackPolling()
        stateChangedCallBack?(self, .playing)
    }

    func pause() {
        mpv?.playback.isPaused = true
        stopPlaybackPolling()
        stateChangedCallBack?(self, .pause)
    }

    func stop() {
        stopPlaybackPolling()
        mpv?.stop()
        stateChangedCallBack?(self, .stop)
    }

    func isEndPosition(_ position: Double) -> Bool {
        return position >= endFlagProgress
    }

    // MARK: - 初始化

    private func setupMpv() {
        guard let view = renderView else { return }
        view.mpvDelegate = self
        self.mpv = view.mpv
    }

    // MARK: - 播放轮询

    private func startPlaybackPolling() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollPlaybackState()
        }
    }

    private func stopPlaybackPolling() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func pollPlaybackState() {
        guard let mpv = mpv, isPlaying else { return }

        if let timeValue = mpv.time.position {
            currentPosition = duration > 0 ? timeValue / duration : 0
            timeChangedCallBack?(self, position)
        }

        if let durationValue = mpv.time.duration, durationValue > 0 {
            if self.duration != durationValue {
                self.duration = durationValue
            }
        }
    }

    // MARK: - 轨道列表更新

    private func updateTrackLists() {
        guard let mpv = mpv else { return }

        subtitleTracks = mpv.track.subtitleTracks.map { track in
            Subtitle(subtitleName: track.displayName, index: 0, trackId: Int(track.id))
        }

        audioTracks = mpv.track.audioTracks.map { track in
            AudioChannel(audioName: track.displayName, audioId: Int32(track.id))
        }
    }

    deinit {
        stopPlaybackPolling()
    }
}

// MARK: - MPVViewDelegate

extension MPVPlayerWrapper: MPVViewDelegate {
    func mpvViewDidLoadFile(_ view: MPVView) {
        updateTrackLists()
    }

    func mpvViewDidEndFile(_ view: MPVView) {
        stopPlaybackPolling()
        stateChangedCallBack?(self, .stop)
    }

    func mpvViewTrackListChanged(_ view: MPVView) {
        updateTrackLists()
    }
}

// MARK: - MPVViewDelegate

protocol MPVViewDelegate: AnyObject {
    func mpvViewDidLoadFile(_ view: MPVView)
    func mpvViewDidEndFile(_ view: MPVView)
    func mpvViewTrackListChanged(_ view: MPVView)
}

// MARK: - MPVView

class MPVView: UIView {

    weak var mpvDelegate: MPVPlayerWrapper?

    private(set) var mpv: MPV?
    private let eventQueue = DispatchQueue(label: "com.anxplayer.mpvview", qos: .userInitiated)

    var onFileLoaded: (() -> Void)?
    var onEndFile: (() -> Void)?
    var onTrackListChanged: (() -> Void)?

    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }

    var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .black
        metalLayer.device = MTLCreateSystemDefaultDevice()
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = UIColor.black.cgColor
        metalLayer.contentsScale = UIScreen.main.scale
        initializeMpv()
    }

    private func initializeMpv() {
        guard let mpvHandle = MPV() else {
            print("[MPVView] failed to create mpv")
            return
        }
        self.mpv = mpvHandle

        // 渲染引擎配置
        mpvHandle.setOptionString(.vo, "gpu-next")
        mpvHandle.setOptionString(.gpuApi, "vulkan")
        mpvHandle.setOptionString(.gpuContext, "moltenvk")
        mpvHandle.video.hardwareDecoding = "videotoolbox"

        // 字幕配置 - 字体设置必须在初始化前完成
        setupSubtitleFonts(mpvHandle: mpvHandle)
        mpvHandle.subtitle.fontSize = 48
        mpvHandle.subtitle.color = UIColor.white
        mpvHandle.subtitle.backColor = UIColor.black.withAlphaComponent(0.5)
        mpvHandle.setOptionString(.subtitleAuto, "exact")
        mpvHandle.setOptionString(.subtitleUseMargins, "no")
        mpvHandle.setOptionString(.subtitleAss, "yes")
        mpvHandle.setOptionString(.subtitleAssOverride, "force")

        // 视频窗口
        let opaque = Unmanaged.passUnretained(metalLayer).toOpaque()
        let rawPtr = Int(bitPattern: opaque)
        mpvHandle.video.windowId = Int64(rawPtr)

        _ = mpvHandle.initialize()

        mpvHandle.observeProperty(.trackList)

        startEventLoop()
    }

    private func setupSubtitleFonts(mpvHandle: MPV) {
        let fontCacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("Fonts")
        let fontNames = [
            "SourceHanSansSC-Regular",
            "SourceHanSansTC-Regular"
        ]

        do {
            try FileManager.default.createDirectory(at: fontCacheDir, withIntermediateDirectories: true)

            for fontName in fontNames {
                let ttfPath = Bundle.main.path(forResource: fontName, ofType: "ttf")
                let otfPath = Bundle.main.path(forResource: fontName, ofType: "otf")
                let sourcePath = ttfPath ?? otfPath
                let ext = ttfPath != nil ? "ttf" : "otf"

                if let bundlePath = sourcePath {
                    let destPath = fontCacheDir.appendingPathComponent("\(fontName).\(ext)")
                    if FileManager.default.fileExists(atPath: destPath.path) {
                        try FileManager.default.removeItem(at: destPath)
                    }
                    try FileManager.default.copyItem(atPath: bundlePath, toPath: destPath.path)
                }
            }

            mpvHandle.setOptionString(.subtitleFontsDir, fontCacheDir.path)
            mpvHandle.setOptionString(.subtitleFont, "SourceHanSansSC-Regular")
        } catch {
            print("[MPVView] Failed to setup fonts: \(error)")
        }
    }

    private func startEventLoop() {
        eventQueue.async { [weak self] in
            self?.eventLoop()
        }
    }

    private func eventLoop() {
        guard let mpv = mpv else { return }

        while true {
            guard let event = mpv.waitEvent(0.1) else { break }
            if event.id == .shutdown {
                break
            }
            handleEvent(event)
        }
    }

    private func handleEvent(_ event: MPVEvent) {
        switch event.id {
        case .propertyChange:
            if event.propertyName == "track-list" {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.mpvDelegate?.mpvViewTrackListChanged(self)
                    self.onTrackListChanged?()
                }
            }
        case .fileLoaded:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.mpvDelegate?.mpvViewDidLoadFile(self)
                self.onFileLoaded?()
            }
        case .endFile:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.mpvDelegate?.mpvViewDidEndFile(self)
                self.onEndFile?()
            }
        default:
            break
        }
    }
}
#endif
