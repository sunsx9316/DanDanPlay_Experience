//
//  MPVPlayerWrapper.swift
//  AniXPlayer
//
//  MPV 播放器封装，实现 MediaPlayerProtocol 接口
//  使用类型安全的 MPV API
//

import Foundation
import ANXLog
#if os(iOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif
import AVFoundation
import MPVFramework

/// MPV 截图错误
enum MPVThumbnailError: Error {
    case noMedia
    case createFailed
    case frameUnavailable
}

/// 把渲染管线产出的帧（BGRA，alpha 字节无意义）转成图片
fileprivate extension CMSampleBuffer {
    func anxImage() -> ANXImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0,
              let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        // 渲染输出为 BGRA（源自 mpv 的 bgr0），用 noneSkipFirst 忽略 alpha，避免生成全透明图片
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(data: baseAddress,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: bitmapInfo),
              let cgImage = context.makeImage() else {
            return nil
        }

        return ANXImage(cgImage: cgImage)
    }
}

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

    /// 最近渲染的一帧，用于"截取当前帧"（懒转换，不逐帧转图）
    private var lastFrameSampleBuffer: CMSampleBuffer?

    /// 独立的 headless 截图器，用于任意进度截图（按媒体复用，不重复创建）
    private var thumbnailer: MediaThumbnailFetcher?

    // MARK: - 媒体视图
    
    private lazy var _mediaView = MPVView(frame: .zero)

    var mediaView: ANXView {
        return _mediaView
    }

    // MARK: - 协议属性

    var currentPlayItem: File? {
        didSet {
            // 媒体变更：清空缓存帧并释放旧截图器
            self.lastFrameSampleBuffer = nil
            self.thumbnailer?.terminate()
            self.thumbnailer = nil

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
        _mediaView.flush()
        renderer.startRendering()
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
        self.lastFrameSampleBuffer = nil
        _mediaView.flush()
        renderer.startRendering()
        mpv?.stop()
        SMBFileManager.shared.stopStreaming()
        stateChangedCallBack?(self, .stop)
    }

    func terminate() {
        ANX.logInfo(.player, "[MPV] 终止")
        self.lastFrameSampleBuffer = nil
        self.thumbnailer?.terminate()
        self.thumbnailer = nil
        renderer.terminate()
        self.mpv?.quit()
        SMBFileManager.shared.stopStreaming()
        stateChangedCallBack?(self, .stop)
    }
    
    /// 截取当前帧（原生分辨率，含字幕），不打断播放
    func fetchThumbnail(completion: @escaping FetchThumbnailAction) {
        guard let sampleBuffer = self.lastFrameSampleBuffer,
              let image = sampleBuffer.anxImage() else {
            ANX.logError(.player, "[MPV] 截图失败：当前帧不可用")
            completion(.failure(MPVThumbnailError.frameUnavailable))
            return
        }

        ANX.logInfo(.player, "[MPV] 截图成功")
        completion(.success(image))
    }

    /// 任意进度缩略图（进度条预览）
    func fetchThumbnail(at position: Float, completion: @escaping FetchThumbnailAction) {
        // 按媒体复用截图器：同一个媒体只创建一次 MPV / MPVMedia
        if self.thumbnailer == nil {
            guard let file = self.currentPlayItem else {
                ANX.logError(.player, "[MPV] 截图失败：没有正在播放的媒体")
                completion(.failure(MPVThumbnailError.noMedia))
                return
            }

            guard let thumbnailer = MediaThumbnailFetcher(file: file) else {
                ANX.logError(.player, "[MPV] 截图失败：创建截图器失败")
                completion(.failure(MPVThumbnailError.createFailed))
                return
            }
            self.thumbnailer = thumbnailer
        }

        guard let thumbnailer = self.thumbnailer else {
            completion(.failure(MPVThumbnailError.createFailed))
            return
        }

        // position 为 0~1 归一化进度，换算成秒
        let seconds = Double(max(min(position, 1), 0)) * self.length
        thumbnailer.fetchThumbnail(position: seconds, completion: completion)
    }
    

    // MARK: - 初始化

    private func initializeMpv() {
        guard let mpvHandle = MPV() else {
            ANX.logError(.player, "[MPV] 创建失败")
            return
        }
        self.mpv = mpvHandle

        // vo=libmpv + SW render context: 渲染到内存 buffer，不依赖 CAMetalLayer swapchain
        mpvHandle.setProperty(.vo, "libmpv")
        let hwdecMode = Preferences.shared.hwdecEnabled ? "videotoolbox" : "no"
        mpvHandle.setProperty(.hwdec, hwdecMode)

        // tvOS: 兼容杜比全景声（系统设置中开启全景声时默认 coreaudio 输出）
#if os(tvOS)
        mpvHandle.setProperty(.audioSpdif, "no")
        mpvHandle.setProperty(.audioChannels, "2")
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
                self?.lastFrameSampleBuffer = sampleBuffer
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
        guard let fontDir = playerPrepareFonts() else { return }
        mpvHandle.setProperty(.subtitleFontsDir, fontDir)
        mpvHandle.setProperty(.subtitleFont, playerCustomFontNames.first ?? "")
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
            cfg.subtitleFontsDir = playerPrepareFonts()
        }
        if cfg.subtitleFont == nil {
            cfg.subtitleFont = playerCustomFontNames.first
        }
        return MPVPiPProvider(config: cfg)
    }
}

// MARK: - 截图（独立 headless mpv 实例）

/// 独立的 headless mpv 实例，用于在任意进度生成截图，与主播放器互不干扰
/// 实例按媒体复用：同一媒体只创建一次 MPV / MPVMedia，之后每次截图只做 seek
fileprivate final class MediaThumbnailFetcher {

    enum ErrorReason: Error {
        case createFailed
        case timeOut
    }

    private var mpv: MPV?
    private let renderer = MPVFrameRenderer()

    /// 本次截图所用的媒体（按媒体复用，只创建一次）
    private let media: MPVMedia

    private var isTerminated = false
    private var isLoaded = false
    private var isLoading = false

    private var completion: ((Result<ANXImage, Error>) -> Void)?
    private var targetPosition: Double = 0
    private var isWaitingForFrame = false
    /// seek 是否已完成（用于丢弃 seek 前的旧帧）
    private var isSeekCompleted = false
    private var timeoutWorkItem: DispatchWorkItem?

    /// 截图超时时间
    private let timeout: TimeInterval = 8

    init?(file: File) {
        guard let media = file.createMPVMedia(), let mpv = MPV() else { return nil }
        self.media = media
        self.mpv = mpv

        // 与主播放器一致的软渲染管线；静音，避免 headless 实例出声
        mpv.setProperty(.vo, "libmpv")
        mpv.setProperty(.hwdec, Preferences.shared.hwdecEnabled ? "videotoolbox" : "no")
        mpv.audio.isMuted = true
        mpv.subtitle.autoLoad = .no
        mpv.subtitle.assOverride = .yes

        guard let handle = mpv.mpv else { return nil }

        renderer.outputScale = 1.0
        renderer.positionProvider = { [weak self] in self?.mpv?.time.position ?? 0 }
        renderer.videoSizeProvider = { [weak self] in self?.mpv?.videoSize ?? .zero }
        renderer.onFrame = { [weak self] sampleBuffer in
            self?.handleFrame(sampleBuffer)
        }

        guard renderer.create(mpvHandle: handle) else {
            ANX.logError(.player, "[MPV] 创建截图渲染上下文失败")
            return nil
        }

        guard mpv.initialize() >= 0 else {
            ANX.logError(.player, "[MPV] 截图器 mpv_initialize 失败")
            return nil
        }

        // 只在文件加载完成后开始渲染，避免截到空帧
        mpv.on(.fileLoaded) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, !self.isTerminated else { return }
                self.isLoaded = true
                self.isLoading = false
                if self.isWaitingForFrame, let mpv = self.mpv {
                    self.beginCapture(mpv: mpv)
                }
            }
        }

        // seek 完成后，等 VO 稳定再主动渲染一帧，确保拿到目标帧
        mpv.on(.seek) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, !self.isTerminated, self.isWaitingForFrame else { return }
                self.isSeekCompleted = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self, !self.isTerminated, self.isWaitingForFrame else { return }
                    self.renderer.requestFrame()
                }
            }
        }
    }

    deinit {
        terminate()
    }

    /// 在指定进度生成截图
    /// - Parameters:
    ///   - position: 目标时间（秒）
    ///   - completion: 主线程回调
    func fetchThumbnail(position: Double, completion: @escaping (Result<ANXImage, Error>) -> Void) {
        guard !isTerminated, let mpv = mpv else {
            completion(.failure(ErrorReason.createFailed))
            return
        }

        self.completion = completion
        self.targetPosition = max(position, 0)
        self.isWaitingForFrame = true
        self.startTimeout()

        if isLoaded {
            beginCapture(mpv: mpv)
        } else if !isLoading {
            isLoading = true
            mpv.loadFile(media.url.absoluteString)
        }
        // 已在加载中：等 fileLoaded 回调按最新 target 开始
    }

    /// 终止并释放实例
    func terminate() {
        guard !isTerminated else { return }
        isTerminated = true
        isLoaded = false
        isLoading = false
        isWaitingForFrame = false
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        completion = nil

        // 先释放渲染上下文，再关闭 mpv
        renderer.terminate()
        mpv?.quit()
        mpv = nil
    }

    // MARK: - 私有

    private func beginCapture(mpv: MPV) {
        ANX.logInfo(.player, "[MPV] 开始截图: \(String(format: "%.1f", targetPosition))s")
        isSeekCompleted = false
        // 暂停：seek 后画面停在目标帧，避免边播边截导致时间偏移
        mpv.playback.isPaused = true

        renderer.startRendering()

        let currentPosition = mpv.time.position ?? 0
        if abs(currentPosition - targetPosition) <= 0.3 {
            // 已停在目标附近，直接渲染
            isSeekCompleted = true
            renderer.requestFrame()
        } else {
            // 精确 seek；渲染在 seek 完成事件里做
            mpv.execute(.seek, args: [String(targetPosition), "absolute+exact"])
        }
    }

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        guard !isTerminated, isWaitingForFrame, isSeekCompleted else { return }

        // 只在目标时间附近取帧：既要丢弃 seek 前的旧帧，也不能接受偏差过大的帧
        let currentPosition = mpv?.time.position ?? 0
        guard abs(currentPosition - targetPosition) <= 0.5 else { return }

        guard let image = sampleBuffer.anxImage() else { return }

        ANX.logInfo(.player, "[MPV] 截图成功: \(String(format: "%.1f", currentPosition))s")
        finishCurrentFetch(.success(image))
    }

    private func startTimeout() {
        timeoutWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            ANX.logError(.player, "[MPV] 截图超时")
            self?.finishCurrentFetch(.failure(ErrorReason.timeOut))
        }
        timeoutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: item)
    }

    private func finishCurrentFetch(_ result: Result<ANXImage, Error>) {
        guard isWaitingForFrame else { return }
        isWaitingForFrame = false
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        // 截图完成后暂停，避免 headless 实例持续解码
        mpv?.playback.isPaused = true

        let completion = self.completion
        self.completion = nil
        completion?(result)
    }
}
