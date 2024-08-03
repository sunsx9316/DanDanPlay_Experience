//
//  MediaSettingModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/3.
//

import Foundation
import RxSwift

private class PlayMediaInfo {
    
    var watchProgressKey: String? {
        if episodeId != 0 {
            return "\(episodeId)"
        }
        return media.fileHash
    }
    
    
    var mediaId: String {
        return self.media.url.path
    }
    
    var playImmediately = false
    
    var episodeId = 0
    
    private let media: File
    
    init(media: File) {
        self.media = media
    }
}

class PlayerMediaContext {
    
    /// 时间信息
    struct TimeInfo {
        let currentTime: TimeInterval
        let totalTime: TimeInterval
    }
    
    lazy var isPlay = BehaviorSubject<Bool>(value: false)
    
    lazy var time = BehaviorSubject<TimeInfo>(value: TimeInfo(currentTime: 0, totalTime: 0))
    
    lazy var buffer = BehaviorSubject<[MediaBufferInfo]?>(value: nil)
    
    lazy var media = BehaviorSubject<File?>(value: nil)
    
    
    lazy var subtitleSafeArea = BehaviorSubject<Bool>(value: Preferences.shared.subtitleSafeArea)
    
    lazy var playerSpeed = BehaviorSubject<Double>(value: Preferences.shared.playerSpeed)
    
    lazy var playerMode = BehaviorSubject<PlayerMode>(value: Preferences.shared.playerMode)
    
    lazy var subtitleOffsetTime = BehaviorSubject<Int>(value: Preferences.shared.subtitleOffsetTime)
    
    lazy var subtitleMargin = BehaviorSubject<Int>(value: Preferences.shared.subtitleMargin)
    
    lazy var subtitleFontSize = BehaviorSubject<Float>(value: Preferences.shared.subtitleFontSize)
    
    lazy var autoJumpTitleEnding = BehaviorSubject<Bool>(value: Preferences.shared.autoJumpTitleEnding)
    
    lazy var jumpTitleDuration = BehaviorSubject<Double>(value: Preferences.shared.jumpTitleDuration)
    
    lazy var jumpEndingDuration = BehaviorSubject<Double>(value: Preferences.shared.jumpEndingDuration)
    
    /// 播放文件事件
    lazy var playMediaEvent = PublishSubject<File>()
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
    
    var subtitleMargin: Int {
        return (try? self.context.subtitleMargin.value()) ?? 0
    }
    
    var subtitleFontSize: Float {
        return (try? self.context.subtitleFontSize.value()) ?? 0
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
        return self.player.currentPlayItem
    }
    
    var isPlaying: Bool {
        return self.player.isPlaying
    }
}

class PlayerMediaModel {
    
    lazy var context = PlayerMediaContext()
    
    private var playMediaInfo = [URL : PlayMediaInfo]()
    
    private lazy var disposeBag = DisposeBag()
    
    
    private lazy var player: MediaPlayer = {
        let player = MediaPlayer(coreType: .vlc)
        player.delegate = self
        return player
    }()
    
    init() {
        bindContext()
    }
    
    deinit {
        self.storeProgress()
    }
    
    // MARK: - Public
    
    // MARK: 工具方法
    func onChangeSubtitleSafeArea(_ subtitleSafeArea: Bool) {
        Preferences.shared.subtitleSafeArea = subtitleSafeArea
        self.context.subtitleSafeArea.onNext(subtitleSafeArea)
    }
    
    func onChangePlayerSpeed(_ playerSpeed: Double) {
        Preferences.shared.playerSpeed = playerSpeed
        self.context.playerSpeed.onNext(playerSpeed)
    }
    
    func onChangePlayerMode(_ playerMode: PlayerMode) {
        Preferences.shared.playerMode = playerMode
        self.context.playerMode.onNext(playerMode)
    }
    
    func onChangeSubtitleOffsetTime(_ subtitleOffsetTime: Int) {
        Preferences.shared.subtitleOffsetTime = subtitleOffsetTime
        self.context.subtitleOffsetTime.onNext(subtitleOffsetTime)
    }
    
    func onChangeSubtitleMargin(_ subtitleMargin: Int) {
        Preferences.shared.subtitleMargin = subtitleMargin
        self.context.subtitleMargin.onNext(subtitleMargin)
    }
    
    func onChangeSubtitleFontSize(_ subtitleFontSize: Float) {
        Preferences.shared.subtitleFontSize = subtitleFontSize
        self.context.subtitleFontSize.onNext(subtitleFontSize)
    }
    
    func onChangeAutoJumpTitleEnding(_ autoJumpTitleEnding: Bool) {
        Preferences.shared.autoJumpTitleEnding = autoJumpTitleEnding
        self.context.autoJumpTitleEnding.onNext(autoJumpTitleEnding)
    }
    
    func onChangeJumpTitleDuration(_ jumpTitleDuration: Double) {
        Preferences.shared.jumpTitleDuration = jumpTitleDuration
        self.context.jumpTitleDuration.onNext(jumpTitleDuration)
    }
    
    func onChangeJumpEndingDuration(_ jumpEndingDuration: Double) {
        Preferences.shared.jumpEndingDuration = jumpEndingDuration
        self.context.jumpEndingDuration.onNext(jumpEndingDuration)
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
            }
        }
    }
    
    
    /// 尝试解析文件
    /// - Parameter media: 文件
    func tryParseMediaOneTime(_ media: File) {
        self.storeProgress()
        
        self.stop()
        
        self.context.media.onNext(media)
    }
    
    /// 保存观看记录
    func storeProgress() {
        if let currentPlayItem = self.player.currentPlayItem,
           let playItem = self.findPlayItem(currentPlayItem),
            let watchProgressKey = playItem.watchProgressKey {
            
            let position = self.player.position
            //播放结束不保存进度
            if position >= 0.99 {
                HistoryManager.shared.cleanWatchProgress(mediaKey: watchProgressKey)
            } else {
                HistoryManager.shared.storeWatchProgress(mediaKey: watchProgressKey, progress: position)
            }
        }
    }
    
    
    /// 检测某个视频是否已经匹配到节目
    /// - Parameter media: 视频
    /// - Returns: 是否已经匹配到节目
    func isMatch(media: File) -> Bool {
        return findPlayItem(media)?.episodeId != 0
    }
    
    
    /// 获取下一个应该播放的视频
    /// - Returns: 下一个应该播放的视频
    func nextMedia() -> File? {
        if let index = self.player.playList.firstIndex(where: { $0.url == self.player.currentPlayItem?.url }) {
            if index != self.player.playList.count - 1 {
                return self.player.playList[index + 1]
            }
        }
        
        return nil
    }
    
    /// 开始播放
    /// - Parameters:
    ///   - media: 视频
    ///   - episodeId: 弹幕分级id
    ///   - danmakus: 弹幕
    func startPlay(_ media: File, episodeId: Int) -> Observable<PlayerModel.MediaLoadState> {
        
        return Observable<PlayerModel.MediaLoadState>.create { [weak self] (sub) in
            
            self?.player.play(media)
            
            _ = self?.loadSubtitle(media)
                .subscribe(onNext: { subtitle in
                    sub.onNext(.subtitle(subtitle: subtitle))
                })
            
            _ = self?.loadLastWatchProgress(media, episodeId: episodeId)
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
        return Observable<Void>.create { (sub) in
            SubtitleManager.shared.downCustomSubtitle(file) { [weak self] result1 in
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
    
    // MARK: - Private
    /// 加载外挂字幕
    /// - Parameter media: 媒体
    /// - Returns: 状态
    private func loadSubtitle(_ media: File) -> Observable<SubtitleProtocol?> {
        return Observable<SubtitleProtocol?>.create { (sub) in
            SubtitleManager.shared.loadLocalSubtitle(media) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let subtitle):
                    self.player.currentSubtitle = subtitle
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
    private func loadLastWatchProgress(_ media: File, episodeId: Int) -> Observable<Double?> {
        return Observable<Double?>.create { [weak self] (sub) in
            
            var lastWatchProgress: Double?
            
            if let playItem = self?.findPlayItem(media) {
                playItem.episodeId = episodeId
                if let watchProgressKey = playItem.watchProgressKey {
                    lastWatchProgress = HistoryManager.shared.watchProgress(mediaKey: watchProgressKey)
                }
            }
            
            DispatchQueue.main.async {
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
    
    private func bindContext() {
        self.context.playerMode.subscribe (onNext: { [weak self] playMode in
            guard let self = self else { return }
            
            self.player.playMode = playMode
        }).disposed(by: self.disposeBag)
        
        self.context.playerSpeed.subscribe (onNext: { [weak self] speed in
            guard let self = self else { return }
            
            self.player.speed = speed
        }).disposed(by: self.disposeBag)
        
        self.context.subtitleOffsetTime.subscribe(onNext: { [weak self] subtitleOffsetTime in
            guard let self = self else { return }
            
            self.player.subtitleDelay = Double(subtitleOffsetTime)
        }).disposed(by: self.disposeBag)
        
        self.context.subtitleMargin.subscribe(onNext: { [weak self] subtitleMargin in
            guard let self = self else { return }
            
            self.player.subtitleMargin = subtitleMargin
        }).disposed(by: self.disposeBag)
        
        self.context.subtitleFontSize.subscribe(onNext: { [weak self] subtitleFontSize in
            guard let self = self else { return }
            
            self.player.fontSize = subtitleFontSize
        }).disposed(by: self.disposeBag)
    }
}


// MARK: - 播放控制
extension PlayerMediaModel {
    
    /// 暂停
    func pause() {
        self.player.pause()
    }
    
    func stop() {
        self.player.stop()
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
    func changePlayState() -> PlayerState {
        if self.player.currentPlayItem != nil {
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
        
        let isPlay = (try? self.context.isPlay.value()) ?? false
        
        switch state {
        case .playing:
            if !isPlay {
                self.context.isPlay.onNext(true)
            }
        case .pause, .stop:
            if isPlay {
                self.context.isPlay.onNext(false)
            }
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
