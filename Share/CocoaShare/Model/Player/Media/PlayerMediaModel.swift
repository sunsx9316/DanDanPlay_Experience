//
//  MediaSettingModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/3.
//

import Foundation
import RxSwift
import ANXLog

private class PlayMediaInfo: HistoryManager.WatchProgressStoreable {
    
    /// 上次播放进度缓存key
    var watchProgressKey: String {
        if let episodeId = matchInfo?.matchId, episodeId != 0 {
            return "\(episodeId)"
        }
        return media.fileId
    }
    
    var matchInfo: MatchInfo?
    
    private let media: File
    
    init(media: File) {
        self.media = media
    }
}

extension PlayerAspectRatio {
    var name: String {
        switch self {
        case .default:
            return NSLocalizedString("默认", comment: "")
        case .fillToScreen:
            return NSLocalizedString("填充屏幕", comment: "")
        case .fourToThree:
            return NSLocalizedString("4:3", comment: "")
        case .sixteenToNine:
            return NSLocalizedString("16:9", comment: "")
        case .sixteenToTen:
            return NSLocalizedString("16:10", comment: "")
        }
    }
}

// MARK: - 便捷接口
extension PlayerMediaModel {
    var mediaView: ANXView {
        return self.player.mediaView
    }
    
    var subtitleSafeArea: Bool {
        return (try? self.context.subtitleSafeArea.value()) ?? false
    }
    
    var playerSpeed: Double {
        return (try? self.context.playerSpeed.value()) ?? 0
    }
    
    var playerMode: PlayerMode {
        return (try? self.context.playerMode.value()) ?? .playOnce
    }
    
    var subtitleOffsetTime: Int {
        return (try? self.context.subtitleOffsetTime.value()) ?? 0
    }
    
    var audioOffsetTime: Int {
        return (try? self.context.audioOffsetTime.value()) ?? 0
    }
    
    var subtitleYPosition: Float {
        return (try? self.context.subtitleYPosition.value()) ?? 0
    }
    
    var subtitleFontSize: CGFloat {
        return CGFloat((try? self.context.subtitleFontSize.value()) ?? 0)
    }
    
    var subtitleFontName: String {
        return (try? self.context.subtitleFontName.value()) ?? ""
    }

    var subtitleColor: ANXColor? {
        return (try? self.context.subtitleColor.value())
    }

    var playerPiP: Bool {
        return (try? self.context.playerPiP.value()) ?? false
    }

    var autoJumpTitleEnding: Bool {
        return (try? self.context.autoJumpTitleEnding.value()) ?? false
    }
    
    var jumpTitleDuration: Double {
        return (try? self.context.jumpTitleDuration.value()) ?? 0
    }
    
    var jumpEndingDuration: Double {
        return (try? self.context.jumpEndingDuration.value()) ?? 0
    }
    
    var playList: [File] {
        return self.player.playList
    }
    
    var currentSubtitle: SubtitleProtocol? {
        get {
            return self.player.currentSubtitle
        }
        
        set {
            self.player.currentSubtitle = newValue
        }
    }
    
    var subtitleList: [SubtitleProtocol] {
        return self.player.subtitleList
    }
    
    var currentAudioChannel: AudioChannelProtocol? {
        get {
            return self.player.currentAudioChannel
        }
        
        set {
            self.player.currentAudioChannel = newValue
        }
    }
    
    var audioChannelList: [AudioChannelProtocol] {
        return self.player.audioChannelList
    }
    
    var position: Double {
        return self.player.position
    }
    
    var length: TimeInterval {
        return self.player.length
    }
    
    var currentTime: TimeInterval {
        return self.player.currentTime
    }
    
    var media: File? {
        return try? self.context.media.value()
    }
    
    var isPlaying: Bool {
        return self.player.isPlaying
    }

    var volume: Int {
        return self.player.volume
    }
    
    var aspectRatio: PlayerAspectRatio {
        return self.player.aspectRatio
    }
    
    var aspectRatioList: [PlayerAspectRatio] {
        return [PlayerAspectRatio.default, PlayerAspectRatio.fourToThree, PlayerAspectRatio.sixteenToNine, PlayerAspectRatio.sixteenToTen]
    }
    
    var mediaSetting: [MediaSettingInfo] {
        var dataSource = [MediaSettingInfo]()
        
        dataSource.append(MediaSettingInfo(title: NSLocalizedString("媒体信息", comment: ""),
                                           dataSource: [.matchInfo]))
        
        var mediaSetting: [MediaSettingType] = [.autoJumpTitleEnding, .jumpTitleDuration, .jumpEndingDuration, .playerSpeed, .playerMode, .aspectRatio, .playerPiP]
        mediaSetting = mediaSetting.filter ({ setting in
            if !self.autoJumpTitleEnding {
                if setting == .jumpTitleDuration || setting == .jumpEndingDuration {
                    return false
                }
            }
            #if os(iOS)
            if self.player.coreType != .mpv {
                if setting == .playerPiP {
                    return false
                }
            }
            #else
            if setting == .playerPiP {
                return false
            }
            #endif
            return true
        })
        
        dataSource.append(MediaSettingInfo(title: NSLocalizedString("播放设置", comment: ""), dataSource: mediaSetting))

        var subtitleSettings: [MediaSettingType] = [.subtitleSafeArea, .subtitleDelay, .subtitleTrack, .loadSubtitle]
        
#if os(iOS) || os(tvOS)
        if self.player.coreType == .mpv {
            subtitleSettings.append(.subtitleStyle)
            if Preferences.shared.subtitleStyle {
                subtitleSettings.append(contentsOf: [.subtitleYPosition, .subtitleFontSize, .subtitleColor])
            }
        } else {
            subtitleSettings.append(contentsOf: [.subtitleYPosition, .subtitleFontSize])
        }
#else
        subtitleSettings.append(contentsOf: [.subtitleYPosition, .subtitleFontSize])
#endif

        dataSource.append(MediaSettingInfo(title: NSLocalizedString("字幕设置", comment: ""),
                                           dataSource: subtitleSettings))
        
        dataSource.append(MediaSettingInfo(title: NSLocalizedString("音频设置", comment: ""),
                                           dataSource: [.audioDelay, .audioTrack]))
        
        return dataSource
    }
}

class PlayerMediaModel {

    var onPiPToggleChanged: ((Bool) -> Void)?

    lazy var context = PlayerMediaContext()
    
    private var playMediaInfo = [URL : PlayMediaInfo]()
    
    private lazy var disposeBag = DisposeBag()
    
    
    private(set) lazy var player: MediaPlayer = {
        let player = MediaPlayer(coreType: Preferences.shared.playerCore)
        player.delegate = self
        return player
    }()
    
    init() {
        bindContext()
    }
    
    deinit {
        self.storeWatchProgress()
    }
    
    // MARK: - Public
    
    // MARK: 工具方法
    func onChangeSubtitleSafeArea(_ subtitleSafeArea: Bool) {
        Preferences.shared.subtitleSafeArea = subtitleSafeArea
        self.context.subtitleSafeArea.onNext(subtitleSafeArea)
        ANX.logInfo(.UI, "更改字幕保护区域: \(subtitleSafeArea)")
    }
    
    func onChangePlayerSpeed(_ playerSpeed: Double) {
        Preferences.shared.playerSpeed = playerSpeed
        self.context.playerSpeed.onNext(playerSpeed)
        ANX.logInfo(.UI, "更改播放速度: \(playerSpeed)")
    }
    
    func onChangePlayerMode(_ playerMode: PlayerMode) {
        Preferences.shared.playerMode = playerMode
        self.context.playerMode.onNext(playerMode)
        ANX.logInfo(.UI, "更改播放模式: \(playerMode)")
    }
    
    func onChangeSubtitleOffsetTime(_ subtitleOffsetTime: Int) {
        Preferences.shared.subtitleOffsetTime = subtitleOffsetTime
        self.context.subtitleOffsetTime.onNext(subtitleOffsetTime)
        ANX.logInfo(.UI, "更改字幕偏移: \(audioOffsetTime)")
    }
    
    func onChangeAudioOffsetTime(_ audioOffsetTime: Int) {
        Preferences.shared.audioOffsetTime = audioOffsetTime
        self.context.audioOffsetTime.onNext(audioOffsetTime)
        ANX.logInfo(.UI, "更改音频偏移: \(audioOffsetTime)")
    }
    
    func onChangeSubtitleYPosition(_ subtitleYPosition: Float) {
        Preferences.shared.subtitleYPosition = subtitleYPosition
        self.context.subtitleYPosition.onNext(subtitleYPosition)
        ANX.logInfo(.UI, "更改字幕Y位置: \(subtitleYPosition)%")
    }
    
    func onChangeSubtitleFontSize(_ subtitleFontSize: Float) {
        Preferences.shared.subtitleFontSize = subtitleFontSize
        self.context.subtitleFontSize.onNext(subtitleFontSize)
        ANX.logInfo(.UI, "更改字体大小: \(subtitleFontSize)")
    }
    
    func onChangeSubtitleFont(_ subtitleFont: ANXFont?) {
        let fontName = subtitleFont?.fontName ?? ""
        Preferences.shared.subtitleFontName = fontName
        self.context.subtitleFontName.onNext(fontName)

        if let subtitleFont = subtitleFont {
            ANX.logInfo(.UI, "更改字幕字体: \(subtitleFont)")
        } else {
            ANX.logInfo(.UI, "更改字幕字体为默认")
        }
    }

    func onChangeSubtitleColor(_ subtitleColor: ANXColor?) {
        Preferences.shared.subtitleColor = subtitleColor
        self.context.subtitleColor.onNext(subtitleColor)
        ANX.logInfo(.UI, "更改字幕颜色")
    }

    func onChangeSubtitleStyle(_ enabled: Bool) {
        Preferences.shared.subtitleStyle = enabled
        self.context.subtitleStyle.onNext(enabled)
        ANX.logInfo(.UI, "更改字幕样式开关: \(enabled)")
    }

    func onChangePlayerPiP(_ enabled: Bool) {
        Preferences.shared.playerPiP = enabled
        self.context.playerPiP.onNext(enabled)
        ANX.logInfo(.UI, "更改画中画开关: \(enabled)")
    }

    // MARK: - PiP

    private(set) var pipManager: PiPManager?

    /// 创建 PiP 播放器实例（headless MPV），配置从主播放器提取（含当前播放状态快照）
    func createPiPPlayer() -> (any PiPPlayerProtocol)? {
        guard let mpvWrapper = player.underlyingPlayer as? MPVPlayerWrapper else {
            ANX.logError(.player, "[PiP] 主播放器不是 MPV，无法创建 PiP 播放器")
            return nil
        }
        var config = PiPPlayerConfig.extract(from: player.underlyingPlayer)
        config.currentSubtitle = player.underlyingPlayer.currentSubtitle
        config.currentAudioChannel = player.underlyingPlayer.currentAudioChannel
        return mpvWrapper.createPiPPlayer(with: config)
    }

    func createPiPManager(with player: any PiPPlayerProtocol, media: File) -> PiPManager {
        let manager = PiPManager()
        self.pipManager = manager
        manager.start(with: player, media: media)
        return manager
    }

    func stopPiP() {
        pipManager?.stop()
        pipManager = nil
    }

    func syncPlayerPosition(_ position: Double, autoPlay: Bool) {
        guard length > 0 else {
            if autoPlay { play() }
            return
        }
        let progress = position / length
        ANX.logInfo(.player, "[PiP] 同步主播放器位置: \(String(format: "%.1f", position))s, autoPlay: \(autoPlay)")
        setPlayerProgress(CGFloat(progress))
        if autoPlay {
            play()
        }
    }

    /// PiP 已切到新集时，主播放器同步切换到该集
    func switchToMedia(_ media: File, autoPlay: Bool) {
        ANX.logInfo(.player, "[PiP] 主播放器切换到: \(media.fileName)")
        player.play(media)
        context.media.onNext(media)
        if !autoPlay {
            pause()
        }
        // 异步加载匹配信息，填充媒体信息 cell
        loadMatchInfoForPiPSync(media)
    }

    /// PiP 切集后静默加载弹幕匹配信息（不显示 HUD）
    private func loadMatchInfoForPiPSync(_ media: File) {
        DanmakuManager.shared.loadDanmaku(media, progress: nil,
            matchCompletion: { _, _ in },
            danmakuCompletion: { [weak self] _, matchInfo, _ in
                guard let self = self,
                      let matchInfo = matchInfo,
                      let playItem = self.findPlayItem(media) else { return }
                playItem.matchInfo = matchInfo
                ANX.logInfo(.player, "[PiP] 匹配信息已更新: \(matchInfo.matchDesc)")
            }
        )
    }

    func onChangeAutoJumpTitleEnding(_ autoJumpTitleEnding: Bool) {
        Preferences.shared.autoJumpTitleEnding = autoJumpTitleEnding
        self.context.autoJumpTitleEnding.onNext(autoJumpTitleEnding)
        ANX.logInfo(.UI, "更改自动跳过片头片尾开关: \(autoJumpTitleEnding)")
    }
    
    func onChangeJumpTitleDuration(_ jumpTitleDuration: Double) {
        Preferences.shared.jumpTitleDuration = jumpTitleDuration
        self.context.jumpTitleDuration.onNext(jumpTitleDuration)
        ANX.logInfo(.UI, "更改自动跳过片头时长: \(jumpTitleDuration)")
    }
    
    func onChangeJumpEndingDuration(_ jumpEndingDuration: Double) {
        Preferences.shared.jumpEndingDuration = jumpEndingDuration
        self.context.jumpEndingDuration.onNext(jumpEndingDuration)
        ANX.logInfo(.UI, "更改自动跳过片尾时长: \(jumpEndingDuration)")
    }
    
    func onChangeVolume(_ addBy: CGFloat) {
        self.player.volume += Int(addBy)
        self.context.volume.onNext(self.player.volume)
        ANX.logInfo(.UI, "更改音量: \(self.player.volume)")
    }
    
    func onChangeAspectRatio(_ aspectRatio: PlayerAspectRatio) {
        Preferences.shared.aspectRatio = aspectRatio
        self.context.aspectRatio.onNext(aspectRatio)
        ANX.logInfo(.UI, "更改宽高比: \(aspectRatio)")
    }
    
    func playerSpeedRange() -> (min: Float, max: Float, step: Float) {
        return (0.5, 3, 0.1)
    }
    
    func jumpTitleDurationRange() -> (min: Float, max: Float, step: Float) {
        return (0, 600, 1)
    }
    
    func jumpEndDurationRange() -> (min: Float, max: Float, step: Float) {
        return (0, 600, 1)
    }
    
    func subtitleYPositionRange() -> (min: Float, max: Float, step: Float) {
        return (0, 100, 1)
    }
    
    func subtitleFontSizeRange() -> (min: Float, max: Float, step: Float) {
        return (10, 120, 1)
    }
    
    func subtitleDelayRange() -> (min: Double, max: Double) {
        return (-500, 500)
    }
    
    func audioDelayRange() -> (min: Double, max: Double) {
        return (-100, 100)
    }
    
    /// 可读的字幕描述
    func subtitleFontReadableName() -> String {
        let tmpSubtitleFontName = self.subtitleFontName
        if tmpSubtitleFontName.isEmpty {
            return NSLocalizedString("默认", comment: "")
        } else {
            return tmpSubtitleFontName + String(format: ": %.1f", self.subtitleFontSize)
        }
    }
    

    /// 加载视频到了列表中
    /// - Parameter medias: 视频
    func loadMedias(_ medias: [File]) {
        for item in medias {
            
            if item.type == .folder {
                continue
            }
            
            let url = item.url
            if self.playMediaInfo[url] == nil {
                let playItem = PlayMediaInfo(media: item)
                self.playMediaInfo[url] = playItem
                self.player.addMediaToPlayList(item)
                self.context.playList.onNext(self.playList)
            }
        }
    }
    
    
    /// 尝试解析文件
    /// - Parameter media: 文件
    func tryParseMediaOneTime(_ media: File) {
        self.storeWatchProgress()
        
        self.stop()
        
        self.context.media.onNext(media)
    }
    
    
    /// 检测某个视频是否已经匹配到节目
    /// - Parameter media: 视频
    /// - Returns: 是否已经匹配到节目
    func isMatch(media: File) -> Bool {
        return findPlayItem(media)?.matchInfo != nil
    }
    
    
    /// 获取匹配信息
    /// - Parameter media: 媒体
    /// - Returns: 匹配信息
    func matchInfo(media: File) -> MatchInfo? {
        return findPlayItem(media)?.matchInfo
    }
    
    
    /// 获取下一个应该播放的视频（不考虑播放模式，纯线性下一项）
    /// - Returns: 下一个应该播放的视频
    func nextMedia() -> File? {
        if let index = self.player.playList.firstIndex(where: { $0 == self.media }) {
            if index != self.player.playList.count - 1 {
                return self.player.playList[index + 1]
            }
        }

        return nil
    }

    /// 根据当前播放模式获取下一集（复用 MediaPlayer 的 playMode 逻辑）
    func nextMediaForPlayMode(from currentItem: File? = nil) -> File? {
        return player.nextPlayItem(from: currentItem)
    }
    
    /// 开始播放
    /// - Parameters:
    ///   - media: 视频
    ///   - matchInfo: 匹配信息
    ///   - danmakus: 弹幕
    func startPlay(_ media: File, matchInfo: MatchInfo?) -> Observable<PlayerModel.MediaLoadState> {
        
        return Observable<PlayerModel.MediaLoadState>.create { [weak self] (sub) in
            
            self?.player.play(media)
            
            _ = self?.loadSubtitle(media)
                .subscribe(onNext: { subtitle in
                    sub.onNext(.subtitle(subtitle: subtitle))
                })
            
            _ = self?.loadLastWatchProgress(media, matchInfo: matchInfo)
                .subscribe(onNext: { [weak self] progress in
                    guard let self = self else { return }
                    
                    if let progress = progress {
                        sub.onNext(.lastWatchProgress(progress: progress))
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.autoJumpTitle()
                        }
                    }
                }, onCompleted: {
                    sub.onCompleted()
                })
            
            return Disposables.create()
        }
    }
    
    
    /// 用户手动加载字幕
    /// - Parameter file: 文件
    /// - Returns: 加载状态
    func loadSubtitleByUser(_ file: File) -> Observable<Void> {
        return Observable<Void>.create { [weak self] (sub) in
            SubtitleManager.shared.downCustomSubtitle(file) { result1 in
                switch result1 {
                case .success(let subtitle):
                    DispatchQueue.main.async {
                        self?.player.currentSubtitle = subtitle
                        sub.onCompleted()
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        sub.onError(error)
                    }
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// 移除文件
    /// - Parameter media: 文件
    func removeMediaFromPlayList(_ media: File) {
        self.player.removeMediaFromPlayList(media)
    }
    
    // MARK: - Private
    /// 加载外挂字幕
    /// - Parameter media: 媒体
    /// - Returns: 状态
    private func loadSubtitle(_ media: File) -> Observable<SubtitleProtocol?> {
        return Observable<SubtitleProtocol?>.create { [weak self] (sub) in
            SubtitleManager.shared.loadLocalSubtitle(media) { result in
                switch result {
                case .success(let subtitle):
                    self?.player.currentSubtitle = subtitle
                    sub.onNext(subtitle)
                case .failure(_):
                    break
                }
                
                sub.onCompleted()
            }
            
            return Disposables.create()
        }
    }
    
    /// 定位上次播放的位置
    private func loadLastWatchProgress(_ media: File, matchInfo: MatchInfo?) -> Observable<Double?> {
        return Observable<Double?>.create { [weak self] (sub) in
            
            var lastWatchProgress: Double?
            
            if let playItem = self?.findPlayItem(media) {
                if let matchInfo = matchInfo {
                    playItem.matchInfo = matchInfo
                }
                
                lastWatchProgress = HistoryManager.shared.watchProgress(media: playItem)
            }
            
            DispatchQueue.main.async {
                ANX.logInfo(.UI, "恢复上次播放进度 key: \(media.fileName), progress：\(lastWatchProgress != nil ? "\(lastWatchProgress!)" : "null")")
                sub.onNext(lastWatchProgress)
                sub.onCompleted()
            }
            
            return Disposables.create()
        }
    }
    
    /// 查找媒体配置
    /// - Parameter protocolItem: 媒体
    /// - Returns: 配置
    private func findPlayItem(_ media: File) -> PlayMediaInfo? {
        if let media = media as? PlayMediaInfo {
            return media
        }
        
        return self.playMediaInfo[media.url]
    }
    
    /// 保存观看进度
    private func storeWatchProgress() {
        if let currentPlayItem = self.media,
           let playItem = self.findPlayItem(currentPlayItem) {
            
            let position = self.player.position
            //播放结束不保存进度
            if position >= 0.99 {
                HistoryManager.shared.storeWatchProgress(media: playItem, progress: nil)
            } else if position > 0 {
                ANX.logInfo(.UI, "保存上次播放进度 key: \(currentPlayItem.fileName), progress：\(position)")
                HistoryManager.shared.storeWatchProgress(media: playItem, progress: position)
            }
        }
    }
    
    
    /// 保存上次观看时间
    private func storeLastWatchDateProgress() {
        if let currentPlayItem = self.media {
            HistoryManager.shared.storeLastWatchDate(media: currentPlayItem, date: Date())
        }
    }
    
    private func bindContext() {
        self.context.aspectRatio.subscribe (onNext: { [weak self] aspectRatio in
            guard let self = self else { return }
            
            self.player.aspectRatio = aspectRatio
        }).disposed(by: self.disposeBag)
        
        self.context.playerMode.subscribe (onNext: { [weak self] playMode in
            guard let self = self else { return }
            
            self.player.playMode = playMode
        }).disposed(by: self.disposeBag)
        
        self.context.playerSpeed.subscribe (onNext: { [weak self] speed in
            guard let self = self else { return }
            
            self.player.speed = speed
        }).disposed(by: self.disposeBag)
        
        /// 字幕开关需要设置在所有字幕属性的前面
        self.context.subtitleStyle
            .subscribe(onNext: { [weak self] on in
            guard let self = self else { return }

            self.player.subtitleStyle = on
        }).disposed(by: self.disposeBag)

        self.context.playerPiP
            .subscribe(onNext: { [weak self] on in
            guard let self = self else { return }
            self.onPiPToggleChanged?(on)
        }).disposed(by: self.disposeBag)
        
        self.context.subtitleOffsetTime.subscribe(onNext: { [weak self] subtitleOffsetTime in
            guard let self = self else { return }
            
            self.player.subtitleOffsetTime = Double(subtitleOffsetTime)
        }).disposed(by: self.disposeBag)
        
        self.context.subtitleYPosition.subscribe(onNext: { [weak self] subtitleYPosition in
            guard let self = self else { return }

            self.player.subtitleYPosition = subtitleYPosition
        }).disposed(by: self.disposeBag)
        
        self.context.subtitleFontName.subscribe(onNext: { [weak self] subtitleFontName in
            guard let self = self else { return }
            
            if subtitleFontName.isEmpty {
                self.player.fontName = nil
            } else {
                self.player.fontName = subtitleFontName
            }
        }).disposed(by: self.disposeBag)
        
        self.context.subtitleFontSize.subscribe(onNext: { [weak self] subtitleFontSize in
            guard let self = self else { return }

            self.player.fontSize = subtitleFontSize
        }).disposed(by: self.disposeBag)

        self.context.subtitleColor.subscribe(onNext: { [weak self] subtitleColor in
            guard let self = self else { return }

            self.player.fontColor = subtitleColor
        }).disposed(by: self.disposeBag)

        if self.player.coreType == .vlc {
            /// 音频延迟设置（仅 VLC 需要延迟，MPV 即时生效）
            self.context.audioOffsetTime
                .delaySubscription(.seconds(2), scheduler: MainScheduler.instance)
                .debounce(.milliseconds(200), scheduler: MainScheduler.instance)
                .subscribe(onNext: { [weak self] audioOffsetTime in
                    guard let self = self else { return }
                    
                    self.player.audioOffsetTime = Double(audioOffsetTime)
                }).disposed(by: self.disposeBag)
        } else {
            self.context.audioOffsetTime
                .subscribe(onNext: { [weak self] audioOffsetTime in
                    guard let self = self else { return }
                    
                    self.player.audioOffsetTime = Double(audioOffsetTime)
                }).disposed(by: self.disposeBag)
        }

    }
}


// MARK: - 播放控制
extension PlayerMediaModel {
    
    /// 播放
    func play() {
        self.player.play()
    }

    /// 暂停
    func pause() {
        self.player.pause()
    }
    
    func stop() {
        self.player.stop()
    }
    
    func terminate() {
        self.player.terminate()
    }
    
    /// 设置播放器进度
    /// - Parameter progress: 进度
    func setPlayerProgress(_ progress: CGFloat) {
        self.player.setPosition(Double(progress))
        self.context.time.onNext(.init(currentTime: self.player.currentTime, totalTime: self.player.length))
    }
    
    /// 设置播放器进度
    /// - Parameters:
    ///   - from: 从什么时间开始，传nil时，默认从当前时间开始
    ///   - diffValue: 差值
    func setPlayerProgress(from: CGFloat? = nil, diffValue: CGFloat) {
        let length = self.player.length
        
        let fromValue = from ?? CGFloat(self.player.currentTime)
        
        if length > 0 {
            let progress = (fromValue + diffValue) / CGFloat(length)
            self.setPlayerProgress(progress)
        }
    }
    
    /// 自动跳过片头
    private func autoJumpTitle() {
        if Preferences.shared.autoJumpTitleEnding {
            let duration = Preferences.shared.jumpTitleDuration
            
            if duration > 0 && self.player.length > 0 && duration < self.player.length {
                self.setPlayerProgress(from: 0, diffValue: duration)
            }
        }
    }
    
    /// 自动跳过片尾
    private func autoJumpEnding() {
        if Preferences.shared.autoJumpTitleEnding {
            let duration = Preferences.shared.jumpEndingDuration
            
            if duration > 0 && self.player.length > 0 {
                
                let shouldJumpEnding = self.player.currentTime + duration >= self.player.length
                && duration < self.player.length
                && self.player.length - self.player.currentTime > 2
                
                if shouldJumpEnding {
                    self.setPlayerProgress(from: 0, diffValue: self.player.length - 1)
                }
            }
        }
    }
    
    /// 更改播放状态
    /// - Returns: 是否是暂停
    @discardableResult func changePlayState() -> PlayerState {
        if self.media != nil {
            if self.player.isPlaying {
                self.player.pause()
            } else {
                self.player.play()
            }
        }
        
        return self.player.state
    }
    
    /// 调整播放器进度
    /// - Parameter position: 进度
    /// - Returns: 调整后视频时间
    func changePosition(_ position: CGFloat) -> TimeInterval {
        self.player.setPosition(position)
        let currentTime = player.length * position
        self.context.time.onNext(.init(currentTime: currentTime, totalTime: player.length))
        return currentTime
    }
}


//MARK: - MediaPlayerDelegate
extension PlayerMediaModel: MediaPlayerDelegate {
    
    func player(_ player: MediaPlayer, stateDidChange state: PlayerState) {
        switch state {
        case .playing:
            self.context.isPlay.onNext(true)
        case .pause, .stop:
            self.context.isPlay.onNext(false)
        }
        
        // fix 未开始播放导致播放记录被覆盖的问题
        if player.currentTime > 0 {
            self.storeWatchProgress()
            self.storeLastWatchDateProgress()
        }
    }
    
    func player(_ player: MediaPlayer, shouldChangeMedia media: File) -> Bool {
        self.context.playMediaEvent.onNext(media)
        return false
    }
    
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        self.context.time.onNext(.init(currentTime: currentTime, totalTime: totalTime))
        self.autoJumpEnding()
    }
    
    func player(_ player: MediaPlayer, file: File, bufferInfoDidChange bufferInfo: MediaBufferInfo) {
        self.context.buffer.onNext(file.bufferInfos)
    }
    
    func playerListDidChange(_ player: MediaPlayer) {
        
    }
    
    func player(_ player: MediaPlayer, mediaDidChange media: File?) {
        
    }
}
