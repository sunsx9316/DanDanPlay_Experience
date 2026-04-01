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
    let trackId: Int64
}

private struct AudioChannel: AudioChannelProtocol {
    let audioName: String
    let audioId: Int64
}

// MARK: - MPVPlayerWrapper

class MPVPlayerWrapper: NSObject, MediaPlayerProtocol {

    // MARK: - 私有属性

    private var mpv: MPV?
    
    private let eventQueue = DispatchQueue(label: "com.anxplayer.mpvwrapper", qos: .userInitiated)

    /// 初始化操作队列
    private var initActions: [() -> Void] = []

    /// 播放轮询定时器
    private var playbackTimer: Timer?

    /// 结束位置阈值
    private let endFlagProgress = 0.99

    // MARK: - 媒体视图

    lazy var mediaView: ANXView = {
        let renderView = MPVView(frame: .zero)
        return renderView
    }()

    // MARK: - 协议属性

    var currentPlayItem: File? {
        didSet {
            if self.mpv == nil {
                initializeMpv()
                for action in self.initActions {
                    action()
                }
            }

            if let item = currentPlayItem,
                let media = item.createMPVMedia() {  
                mpv?.loadFile(media.url.absoluteString)
            }
        }
    }

    var subtitleList: [SubtitleProtocol] {
        return _subtitleList
    }
    private lazy var _subtitleList = [Subtitle]()

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

            if self.mpv != nil {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var audioChannelList: [AudioChannelProtocol] {
        return _audioChannelList
    }
    private lazy var _audioChannelList = [AudioChannel]()

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
            let setup = { [weak self] in
                guard let self = self else { return }
                if let channel = newValue {
                    self.mpv?.audio.audioId = Int64(channel.audioId)
                }
            }

            if self.mpv != nil {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var timeChangedCallBack: ((MediaPlayerProtocol, Double) -> Void)?
    var stateChangedCallBack: ((MediaPlayerProtocol, PlayerState) -> Void)?
    var bufferInfoDidChangeCallBack: ((MediaPlayerProtocol, File, MediaBufferInfo) -> Void)?
    var endOfFileCallBack: ((MediaPlayerProtocol) -> Void)?

    var volume: Int = 100 {
        didSet {
            let setup = { [weak self] in
                guard let self = self else { return }
                self.mpv?.audio.volume = Int64(self.volume)
            }

            if self.mpv != nil {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var subtitleOffsetTime: Double {
        get {
            // MPV sub-delay 负值表示延后，正值表示提前
            // 取反后：正值=延后，负值=提前，与 VLC 语义一致
            return -(self.mpv?.subtitle.delay ?? 0)
        }
        set {
            let setup = { [weak self] in
                guard let self = self else { return }
                self.mpv?.subtitle.delay = -newValue
            }

            if self.mpv != nil {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var audioOffsetTime: Double {
        get {
            // MPV audio-delay 负值表示延后，正值表示提前
            // 取反后：正值=延后，负值=提前，与 VLC 语义一致
            return -(self.mpv?.audio.delay ?? 0)
        }
        set {
            let setup = { [weak self] in
                guard let self = self else { return }
                self.mpv?.audio.delay = -newValue
            }

            if self.mpv != nil {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var speed: Double = 1.0 {
        didSet {
            let setup = { [weak self] in
                guard let self = self else { return }
                self.mpv?.playback.setSpeed(self.speed)
            }

            if self.mpv != nil {
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

            if self.mpv != nil {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    var subtitleYPosition: Float = 0 {
        didSet {
            let setup = { [weak self] in

                guard let self = self else { return }

                // 获取视图高度（考虑缩放比例）
                let scaleFactor: CGFloat
                #if os(iOS)
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
                self.mpv?.setOptionString(.subtitleMarginY, "\(bottom)")

                // sub-pos: 100=原始位置，<100往上移
                // percent=0 时贴近底部（原始位置），percent=100 时贴近顶部
                let posValue = 100 - percent
                self.mpv?.setOptionString(.subtitlePos, "\(posValue)")

                // sub-ass-override=force 确保覆盖 ASS 内嵌样式
                self.mpv?.setOptionString(.subtitleAssOverride, "force")

                // 使用 ASS 命令 \margins(l,t,r,b)
                self.mpv?.execute(.set, args: ["sub-ass", "\\margins(0,\(bottom),0,\(bottom))"])
            }

            if self.mpv != nil {
                setup()
            } else {
                initActions.append(setup)
            }
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
            let setup = { [weak self] in
                guard let self = self else { return }
                self.mpv?.subtitle.fontSize = Int64(size)
            }

            if self.mpv != nil {
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
            let setup = { [weak self] in
                guard let self = self else { return }
                self.mpv?.subtitle.color = self.fontColor
            }

            if self.mpv != nil {
                setup()
            } else {
                initActions.append(setup)
            }
        }
    }

    // MARK: - 协议方法

    func setPosition(_ position: Double) {
        let pos = max(min(position, 1), 0)
        let time = pos * self.length
        mpv?.time.seek(to: time)
    }

    func play(_ media: File) {
        currentPlayItem = media
        play()
    }

    func play() {
        mpv?.playback.isPaused = false
        startPlaybackPolling()
    }

    func pause() {
        mpv?.playback.isPaused = true
        stopPlaybackPolling()
    }

    func stop() {
        stopPlaybackPolling()
        mpv?.stop()
        stateChangedCallBack?(self, .stop)
    }
    
    func terminate() {
        stopPlaybackPolling()
        self.mpv?.quit()
        stateChangedCallBack?(self, .stop)
    }

    // MARK: - 初始化
    
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
        mpvHandle.setOptionString(.subtitleAuto, "no") // 不自动加载字幕
        mpvHandle.setOptionString(.subtitleAss, "yes") // 渲染ass特效
        mpvHandle.setOptionString(.subtitleAssOverride, "force") //覆盖ass样式

        // 视频窗口
        let opaque = Unmanaged.passUnretained(self.mediaView.layer).toOpaque()
        let rawPtr = Int(bitPattern: opaque)
        mpvHandle.video.windowId = Int64(rawPtr)

        mpvHandle.initialize()

        mpvHandle.observeProperty(.trackList, id: 1)
        mpvHandle.observeProperty(.pause, id: 2)
        mpvHandle.observeProperty(.endOfReached, id: 3)

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
        while true {
            guard let event = self.mpv?.waitEvent(0.1) else { break }
            
            if event.id == .shutdown {
                self.mpv?.video.windowId = 0
                self.mpv = nil
                break
            } else {
                handleEvent(event)
            }
        }
    }

    private func handleEvent(_ event: MPVEvent) {
        switch event.id {
        case .propertyChange:
            if event.propertyName == "track-list" {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.updateTrackLists()
                }
            } else if event.propertyName == "pause" {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let isPaused = self.mpv?.playback.isPaused ?? false
                    self.stateChangedCallBack?(self, isPaused ? .pause : .playing)
                }
            }
        case .fileLoaded:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateTrackLists()
            }
        case .endFile:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.stopPlaybackPolling()
                self.stateChangedCallBack?(self, .stop)
                self.endOfFileCallBack?(self)
            }
        default:
            break
        }
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
            Subtitle(subtitleName: track.displayName, trackId: track.id)
        }

        _audioChannelList = mpv.track.audioTracks.map { track in
            AudioChannel(audioName: track.displayName, audioId: track.id)
        }
    }

    deinit {
        stopPlaybackPolling()
    }
}

// MARK: - MPVView

class MPVView: UIView {

    override class var layerClass: AnyClass {
        return CAMetalLayer.self
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
        
        if let metalLayer = self.layer as? CAMetalLayer {
            metalLayer.device = MTLCreateSystemDefaultDevice()
            metalLayer.pixelFormat = .bgra8Unorm
            metalLayer.framebufferOnly = true
            metalLayer.backgroundColor = UIColor.black.cgColor
            metalLayer.contentsScale = UIScreen.main.scale
        }
    }
}
#endif
