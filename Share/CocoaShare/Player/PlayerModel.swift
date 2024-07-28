//
//  PlayerModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/27.
//

import Foundation
import DanmakuRender
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

class PlayerModel {
    
    /// 时间信息
    struct TimeInfo {
        let currentTime: TimeInterval
        let totalTime: TimeInterval
    }
    
    /// 解析错误
    enum ParseError: Error {
        case notMatched(collection: MatchCollection, media: File)
    }
    
    /// 视频加载状态
    enum MediaLoadState {
        case parse(state: LoadingState, progress: Float)
        case subtitle(subtitle: SubtitleProtocol?)
        case lastWatchProgress(progress: Double)
    }
    
    lazy var isPlay = BehaviorSubject<Bool>(value: false)
    
    lazy var time = BehaviorSubject<TimeInfo>(value: TimeInfo(currentTime: 0, totalTime: 0))
    
    lazy var buffer = BehaviorSubject<[MediaBufferInfo]?>(value: nil)
    
    lazy var media = BehaviorSubject<File?>(value: nil)
    
    lazy var parseMediaState = PublishSubject<Event<MediaLoadState>>()
    
    var mediaView: ANXView {
        return self.player.mediaView
    }
    
    var danmakuView: ANXView {
        return self.danmakuRender.canvas
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
    
    var speed: Double {
        return self.player.speed
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
    
    /// 当前弹幕的时间
    private var danmakuTime: UInt?
    
    
    private lazy var danmakuRender: DanmakuEngine = {
        let danmakuRender = DanmakuEngine()
        danmakuRender.layoutStyle = .nonOverlapping
        return danmakuRender
    }()
    
    private var playMediaInfo = [URL : PlayMediaInfo]()
    
    //当前弹幕时间/弹幕数组映射
    private var danmakuDic = DanmakuMapResult()
    
    /// 记录当前屏幕展示的弹幕
    private lazy var danmuOnScreenMap = NSMapTable<NSString, BaseDanmaku>.strongToWeakObjects()
    
    /// 弹幕字体
    private lazy var danmakuFont = DRFont.systemFont(ofSize: CGFloat(Preferences.shared.danmakuFontSize))
    
    
    private lazy var player: MediaPlayer = {
        let player = MediaPlayer(coreType: .vlc)
        player.delegate = self
        return player
    }()
    
    deinit {
        self.storeProgress()
    }
    
    // MARK: 工具方法
    /// 应用偏好设置
    func initPreferences() {
        self.danmakuFont = DRFont.systemFont(ofSize: CGFloat(Preferences.shared.danmakuFontSize))
        self.danmakuRender.offsetTime = TimeInterval(Preferences.shared.danmakuOffsetTime)
        self.changeRepeatMode(playerMode: Preferences.shared.playerMode)
        self.changeSpeed(Preferences.shared.playerSpeed)
        self.changeSubtltleDelay(subtitleDelay: Preferences.shared.subtitleOffsetTime)
        self.changeSubtitleMargin(subtitleMargin: Preferences.shared.subtitleMargin)
        self.changeSubtitleFontSize(fontSize: Preferences.shared.subtitleFontSize)
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
    
    
    /// 用户手动加载弹幕
    /// - Parameter file: 文件
    /// - Returns: 加载状态
    func loadDanmakuByUser(_ file: File) -> Observable<Void> {
        
        let sub = PublishSubject<Void>()
        
        DanmakuManager.shared.downCustomDanmaku(file) { [weak self] result1 in
            
            guard let self = self else { return }
            
            switch result1 {
            case .success(let url):
                do {
                    let converResult = try DanmakuManager.shared.conver(url)
                    DispatchQueue.main.async {
                        self.danmakuDic = converResult
                        
                        sub.onCompleted()
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        sub.onError(error)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    sub.onError(error)
                }
            }
        }
        
        return sub
    }
    
    /// 用户手动加载字幕
    /// - Parameter file: 文件
    /// - Returns: 加载状态
    func loadSubtitleByUser(_ file: File) -> Observable<Void> {
        let sub = PublishSubject<Void>()
        
        SubtitleManager.shared.downCustomSubtitle(file) { result1 in
            switch result1 {
            case .success(let subtitle):
            DispatchQueue.main.async {
                self.player.currentSubtitle = subtitle
                sub.onCompleted()
            }
            case .failure(let error):
                DispatchQueue.main.async {
                    sub.onError(error)
                }
            }
        }
        
        return sub
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
    
    /// 发送胆码
    /// - Parameter danmaku: 弹幕
    func sendDanmaku(_ danmaku: Comment) {
        //            if !text.isEmpty {
        //                let danmaku = DanmakuModel()
        //                danmaku.mode = .normal
        //                danmaku.time = self.danmakuRender.currentTime + self.danmakuRender.offsetTime
        //                danmaku.message = text
        //                danmaku.id = "\(Date().timeIntervalSince1970)"
        //
        //                let msg = SendDanmakuMessage()
        //                msg.danmaku = danmaku
        //                msg.episodeId = episodeId
        //                #warning("待处理")
        ////                MessageHandler.sendMessage(msg)
        //
        ////                self.danmakuRender.sendDanmaku(DanmakuManager.shared.conver(danmaku))
        //            }
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
    
   
    
    /// 查找媒体配置
    /// - Parameter protocolItem: 媒体
    /// - Returns: 配置
    private func findPlayItem(_ media: File) -> PlayMediaInfo? {
        if let media = media as? PlayMediaInfo {
            return media
        }
        
        return self.playMediaInfo[media.url]
    }
    
}

// MARK: - 加载视频全流程
extension PlayerModel {
    /// 解析视频，状态会传递给parseMediaState
    /// - Parameter media: 视频
    func tryParseMedia(_ media: File) {
        _ = self.tryParseMediaOneTime(media).subscribe { [weak self] event in
            guard let self = self else { return }
            
            self.parseMediaState.on(.next(event))
        }
    }
    
    
    /// 单次解析视频
    /// - Parameter media: 视频
    /// - Returns: 状态
    private func tryParseMediaOneTime(_ media: File) -> Observable<MediaLoadState> {
        
        let sub = PublishSubject<MediaLoadState>()
        
        self.storeProgress()
        
        self.player.stop()
        
        self.media.onNext(media)
        
        DanmakuManager.shared.loadDanmaku(media) { state in
            DispatchQueue.main.async {
                
                switch state {
                case .parseMedia:
                    sub.onNext(.parse(state: state, progress: 0))
                case .downloadLocalDanmaku:
                    sub.onNext(.parse(state: state, progress: 0.2))
                case .matchMedia(progress: let progress):
                    sub.onNext(.parse(state: state, progress: Float(0.2 + 0.6 * progress)))
                case .downloadDanmaku:
                    sub.onNext(.parse(state: state, progress: 0.9))
                }
            }
        } matchCompletion: { (collection, error) in
            DispatchQueue.main.async {
                
                if let error = error {
                    sub.onError(error)
                } else if let collection = collection {
                    sub.onError(ParseError.notMatched(collection: collection, media: media))
                }
                
                sub.onCompleted()
            }
        } danmakuCompletion: { result, episodeId, error in
            DispatchQueue.main.async {
                
                if let error = error {
                    sub.onError(error)
                } else {
                    _ = self.startPlay(media, episodeId: episodeId, danmakus: result ?? [:]).subscribe(onNext: { state in
                        sub.onNext(state)
                    }, onCompleted: {
                        sub.onCompleted()
                    })
                }
            }
        }
        
        return sub
    }
    
    
    /// 匹配后的流程，比如加载弹幕
    /// - Parameters:
    ///   - media: 视频
    ///   - episodeId: 节目id
    /// - Returns: 加载状态
    func didMatchMedia(_ media: File, episodeId: Int) -> Observable<MediaLoadState>  {
        let sub = PublishSubject<MediaLoadState>()
        
        CommentNetworkHandle.getDanmaku(with: episodeId) { [weak self] (collection, error) in
            
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    sub.onError(error)
                }
            } else {
                let danmakus = collection?.collection ?? []
                DispatchQueue.main.async {
                    _ = self.startPlay(media, episodeId: episodeId, danmakus: DanmakuManager.shared.conver(danmakus)).subscribe { event in
                        sub.on(event)
                    }
                }
            }
        }
        
        
        return sub
    }
    
    /// 开始播放
    /// - Parameters:
    ///   - media: 视频
    ///   - episodeId: 弹幕分级id
    ///   - danmakus: 弹幕
    func startPlay(_ media: File, episodeId: Int, danmakus: DanmakuMapResult) -> Observable<MediaLoadState> {
        
        let sub = PublishSubject<MediaLoadState>()
        
        self.danmakuDic = danmakus
        self.danmakuRender.time = 0
        self.danmakuTime = nil
        self.player.play(media)
        
        _ = self.loadSubtitle(media)
            .subscribe(onNext: { subtitle in
                sub.onNext(.subtitle(subtitle: subtitle))
            })
        
        _ = self.loadLastWatchProgress(media, episodeId: episodeId)
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
        
        return sub
    }
    
    
    /// 加载外挂字幕
    /// - Parameter media: 媒体
    /// - Returns: 状态
    private func loadSubtitle(_ media: File) -> Observable<SubtitleProtocol?> {
        
        let sub = PublishSubject<SubtitleProtocol?>()
        
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
        
        return sub
    }
    
    /// 定位上次播放的位置
    private func loadLastWatchProgress(_ media: File, episodeId: Int) -> Observable<Double?> {
        let sub = PublishSubject<Double?>()
        
        var lastWatchProgress: Double?
        
        if let playItem = self.findPlayItem(media) {
            playItem.episodeId = episodeId
            if let watchProgressKey = playItem.watchProgressKey {
                lastWatchProgress = HistoryManager.shared.watchProgress(mediaKey: watchProgressKey)
            }
        }
        
        DispatchQueue.main.async {
            sub.onNext(lastWatchProgress)
            sub.onCompleted()
        }

        return sub
    }
}

// MARK: - 播放控制
extension PlayerModel {
    
    /// 暂停
    func pause() {
        self.player.pause()
    }
    
    /// 设置播放器进度
    /// - Parameter progress: 进度
    func setPlayerProgress(_ progress: CGFloat) {
        self.player.setPosition(Double(progress))
        self.time.onNext(.init(currentTime: self.player.currentTime, totalTime: self.player.length))
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
    
    func changeRepeatMode(playerMode: Preferences.PlayerMode) {
        switch playerMode {
        case .notRepeat:
            player.playMode = .autoPlayNext
        case .repeatAllItem:
            player.playMode = .repeatList
        case .repeatCurrentItem:
            player.playMode = .repeatCurrentItem
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
        } else {
            /// 当前没有播放的对象，尝试解析视频
//            self.parseMediaAtInit()
        }
        
        return self.player.state
    }
    
    /// 调整速度
    /// - Parameter speed: 速度
    func changeSpeed(_ speed: Double) {
        self.player.speed = speed
        self.danmakuRender.speed = speed
    }
    
    /// 调整延迟
    /// - Parameter subtitleDelay: 延迟时间
    func changeSubtltleDelay(subtitleDelay: Int) {
        self.player.subtitleDelay = Double(subtitleDelay)
    }
    
    /// 调整字幕Y轴偏移
    /// - Parameter subtitleMargin: Y轴偏移
    func changeSubtitleMargin(subtitleMargin: Int) {
        self.player.subtitleMargin = subtitleMargin
    }
    
    /// 调整字幕大小
    /// - Parameter fontSize: <#fontSize description#>
    func changeSubtitleFontSize(fontSize: Float) {
        self.player.fontSize = fontSize
    }
    
    /// 更改弹幕速度
    /// - Parameter speed: 速度
    func changeDanmakuSpeed(_ speed: Float) {
        self.forEachDanmakus { danmaku in
            if let scrollDanmaku = danmaku as? ScrollDanmaku {
                scrollDanmaku.extraSpeed = CGFloat(speed)
            }
        }
    }
    
    
    /// 更改弹幕大小
    /// - Parameter fontSize: 字体大小
    func changeDanmakuFontSize(fontSize: CGFloat) {
        self.danmakuFont = DRFont.systemFont(ofSize: fontSize)
        self.forEachDanmakus { danmaku in
            danmaku.font = self.danmakuFont
        }
    }
    
    /// 修改弹幕偏移时间
    /// - Parameter offsetTime: 偏移时间
    func setDanmakuOffsetTime(_ offsetTime: TimeInterval) {
        self.danmakuRender.offsetTime = offsetTime
    }
}

//MARK: - MediaPlayerDelegate
extension PlayerModel: MediaPlayerDelegate {
    
    func player(_ player: MediaPlayer, stateDidChange state: PlayerState) {
        switch state {
        case .playing:
            self.isPlay.onNext(true)
            self.danmakuRender.start()
        case .pause, .stop:
            self.isPlay.onNext(false)
            self.danmakuRender.pause()
        }
    }
    
    func player(_ player: MediaPlayer, shouldChangeMedia media: File) -> Bool {
        
        self.tryParseMedia(media)
        return false
    }
    
    func player(_ player: MediaPlayer, mediaDidChange media: File?) {
        
    }
    
    func player(_ player: MediaPlayer, didChangePosition: Double, mediaTime: TimeInterval) {
        self.danmakuRender.time = mediaTime
        self.time.onNext(.init(currentTime: mediaTime, totalTime: player.length))
    }
    
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        self.time.onNext(.init(currentTime: currentTime, totalTime: totalTime))
        self.sendDanmakus(at: currentTime)
        self.autoJumpEnding()
    }
    
    func player(_ player: MediaPlayer, file: File, bufferInfoDidChange bufferInfo: MediaBufferInfo) {
        self.buffer.onNext(file.bufferInfos)
    }
    
    func playerListDidChange(_ player: MediaPlayer) {
        
    }
    
    /// 遍历当前的弹幕
    /// - Parameter callBack: 回调
    private func forEachDanmakus(_ callBack: (BaseDanmaku) -> Void) {
        for con in danmakuRender.containers {
            if let danmaku = con.danmaku as? BaseDanmaku {
                callBack(danmaku)
            }
        }
    }
    
    /// 发送弹幕
    private func sendDanmakus(at currentTime: TimeInterval) {
        
        let danmakuRenderTime = currentTime + self.danmakuRender.offsetTime
        
        if danmakuRenderTime < 0 {
            return
        }
        
        let intTime = UInt(danmakuRenderTime)
        /// 一秒只发射一次弹幕
        if intTime == self.danmakuTime {
            return
        }
        
        self.danmakuTime = intTime
        if let danmakus = danmakuDic[intTime] {
            let danmakuDensity = Preferences.shared.danmakuDensity
            for danmakuBlock in danmakus {
                /// 小于弹幕密度才允许发射
                let shouldSendDanmaku = Float.random(in: 0...10) <= danmakuDensity
                if shouldSendDanmaku {
                    let danmaku = danmakuBlock()
                    
                    /// 修复因为时间误差的问题，导致少数弹幕突然出现在屏幕上的问题
                    if danmaku.appearTime > 0 {
                        danmaku.appearTime = self.danmakuRender.time + (danmaku.appearTime - Double(intTime))
                    }
                    
                    /// 合并弹幕启用时，查找屏幕上与本弹幕文案相同的弹幕，进行更新
                    if Preferences.shared.isMergeSameDanmaku {
                        let danmakuTextKey = danmaku.text as NSString

                        /// 文案与当前弹幕相同
                        if let oldDanmaku = self.danmuOnScreenMap.object(forKey: danmakuTextKey) as? DanmakuEntity {
                            oldDanmaku.repeatDanmakuInfo?.repeatCount += 1
                            self.danmakuRender.update(oldDanmaku)
                        } else {
                            danmaku.repeatDanmakuInfo = .init(danmaku: danmaku)
                            
                            self.danmakuRender.send(danmaku)
                            self.danmuOnScreenMap.setObject(danmaku, forKey: danmakuTextKey)
                        }
                    } else {
                        self.danmakuRender.send(danmaku)
                    }
                    
                }
            }
        }
    }
}
