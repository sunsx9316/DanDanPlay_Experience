//
//  VLCPlayerWarrper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/10/2.
//

import Foundation
import ANXLog
import VLCKit
#if os(iOS)
import YYCategories
#endif

fileprivate extension Timer {
    class func mp_scheduledTimer(timeInterval ti: TimeInterval, repeats yesOrNo: Bool, action: @escaping((Timer) -> Void)) -> Timer {
        return Timer.scheduledTimer(timeInterval: ti, target: self, selector: #selector(mp_timerStart(_:)), userInfo: action, repeats: yesOrNo)
    }

    @objc private class func mp_timerStart(_ sender: Timer) {
        let action = sender.userInfo as? (Timer) -> Void
        action?(sender)
    }
}

extension VLCMediaPlayer.Track: SubtitleProtocol {
    var subtitleName: String {
        return self.trackName;
    }
    
    var isExternalSubtitle: Bool {
        return codecName() == "Text subtitles with various tags"
    }
}

extension VLCMediaPlayer.Track: AudioChannelProtocol {
    var audioName: String {
        return self.trackName
    }
    
}

/// 内嵌字幕
private struct Subtitle: SubtitleProtocol {
    let subtitleName: String
    
    let index: Int
}

/// 外挂字幕
struct ExternalSubtitle: SubtitleProtocol {
    let subtitleName: String
    
    let url: URL
}

struct AudioChannel: AudioChannelProtocol {
    let audioName: String
    
    let audioId: Int32
}

fileprivate class SubtitleTaskQueue {
    
    typealias CompletionAction = (String) -> Void
    typealias StartAction = () -> Void
    
    class Task {
        var completionCallBack: (CompletionAction)?
        var startCallBack: (StartAction)?
        
        init(startCallBack: @escaping(StartAction), completionCallBack: @escaping(CompletionAction)) {
            self.completionCallBack = completionCallBack
            self.startCallBack = startCallBack
        }
        
        func start() {
            self.startCallBack?()
        }
        
        func completion(trackId: String) {
            self.completionCallBack?(trackId)
        }
    }
    
    private lazy var taskQueue = [Task]()
    
    private(set) var currentTask: Task?
    
    func AddTask(task: Task) {
        taskQueue.append(task)
        let oldCompletionCallBack = task.completionCallBack
        task.completionCallBack = { [weak self] trackId in
            /// 任务完成，移除队列
            self?.taskQueue.removeAll { aTask in
                return aTask === task
            }
            
            oldCompletionCallBack?(trackId)
            
            /// 开启下一个任务
            self?.startNext()
        }
        
        startNext()
    }
    
    private func startNext() {
        self.currentTask = self.taskQueue.first
        self.currentTask?.start()
    }
    
}

class VLCPlayerWarrper: NSObject, MediaPlayerProtocol {
    
    private enum Options: String {
        case subtitleMargin = "--sub-margin"
//        case subtitleTextScale = "--sub-text-scale"
//        case subtitleColor = "--freetype-color"
//        case subtitleName = "--freetype-font"
    }
    
    private enum InitAction {
        case currentSubtitle
        case volume
        case subtitleOffsetTime
        case speed
        case currentAudioChannel
        case aspectRatio
        case audioOffsetTime
        case subtitleFontName
        case subtitleFontSize
    }

    
    private var player: VLCMediaPlayer?
    
    fileprivate var playerTimer: Timer?
    
    fileprivate var timeIsUpdate = false
    
    private let endFlagProgress = 0.99
    
    private lazy var externalSubTitleFiles = [String: ExternalSubtitle]()
    
    private var mediaThumbnailer: MediaThumbnailer?
    
    lazy var mediaView: ANXView = {
        let view = ANXView()
        view.backgroundColor = .black
        return view
    }();
    
    private lazy var mediaOptionsDic = [Options: Any]()
    
    private lazy var initActionDic = [InitAction: () -> Void]()
    
    private lazy var subtitleTaskQueue = SubtitleTaskQueue()
    
    var currentPlayItem: File? {
        didSet {
            
            if self.player == nil {
                self.player = self.createPlayerInstance()
                for (_, initAction) in self.initActionDic {
                    initAction()
                }
            }
            
            self.player?.stop()
            self.externalSubTitleFiles.removeAll()
            let media = self.currentPlayItem?.createMedia(delegate: self)
            self.player?.media = media
#if os(macOS)
            media?.synchronousParse()
#endif
            if let media = media {
                self.mediaThumbnailer = .init(media: media)
            } else {
                self.mediaThumbnailer = nil
            }
        }
    }
    
    var subtitleList: [SubtitleProtocol] {
        
        var tracks = [SubtitleProtocol]()
        
        /// 内嵌字幕
        if let innerTrack = self.player?.textTracks.filter ({ track in
            return self.externalSubTitleFiles[track.trackId] == nil && !track.isExternalSubtitle
        }) {
            tracks.append(contentsOf: innerTrack)
        }
        
        let arr = Array(self.externalSubTitleFiles.values)
        tracks.append(contentsOf: arr)
        
        return tracks
    }
    
    var currentSubtitle: SubtitleProtocol? {
        get {
            
            guard let player = self.player else { return nil }
            
            if let selectedSubtitle = player.textTracks.first(where: { track in
                return track.isSelected
            }) {
                if let externalSubTitleFile = self.externalSubTitleFiles[selectedSubtitle.trackId] {
                    return externalSubTitleFile
                }
                
                return selectedSubtitle
            }
            
            return nil
        }
        
        set {
            
            func setSubtitleTrack(trackId: String) {
                if let firstIndex = player?.textTracks.firstIndex(where: { track in
                    return track.trackId == trackId
                }) {
                    self.player?.selectTrack(at: firstIndex, type: .text)
                }
            }
            
            func setup() {
                
                if let sub = newValue as? VLCMediaPlayer.Track {
                    setSubtitleTrack(trackId: sub.trackId)
                } else if let sub = newValue as? ExternalSubtitle {
                    
                    for (key, aSub) in self.externalSubTitleFiles {
                        /// 已加载的外部字幕
                        if aSub.url == sub.url {
                            setSubtitleTrack(trackId: key)
                            return
                        }
                    }
                    
                    self.subtitleTaskQueue.AddTask(task: SubtitleTaskQueue.Task(startCallBack: { [weak self] in
                        let result = self?.player?.addPlaybackSlave(sub.url, type: .subtitle, enforce: true) ?? 0
                        ANX.logInfo(.subtitle, "加载外部字幕 url: \(sub.url) result:\(result)")
                    }, completionCallBack: { [weak self] trackId in
                        /// 存储Track和外部文件的映射关系
                        self?.externalSubTitleFiles[trackId] = sub
                        setSubtitleTrack(trackId: trackId)
                    }))
                }
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.currentSubtitle] = setup
        }
    }
    
    var subtitleMargin: Int {
        get {
            return Int(self.mediaOptionsDic[.subtitleMargin] as? Int ?? 0)
        }
        
        set {
            if newValue != (self.mediaOptionsDic[.subtitleMargin] as? Int) {
                self.mediaOptionsDic[.subtitleMargin] = newValue
                self.reloadOptionAndCreatePlayer()
            }
        }
    }
    
    var volume: Int {
        get {
            return Int(self.player?.audio?.volume ?? 0)
        }
        
        set {
            
            func setup() {
                self.player?.audio?.volume = Int32(newValue)
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.volume] = setup
        }
    }
    
    var subtitleOffsetTime: Double {
        get {
            return Double(self.player?.currentVideoSubTitleDelay ?? 0) / -1000000.0
        }
        
        set {
            func setup() {
                self.player?.currentVideoSubTitleDelay = Int(newValue * -1000000.0)
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.subtitleOffsetTime] = setup
        }
    }
    
    var audioOffsetTime: Double {
        get {
            return Double(self.player?.currentAudioPlaybackDelay ?? 0) / -1000000.0
        }
        
        set {
            func setup() {
                self.player?.currentAudioPlaybackDelay = Int(newValue * -1000000.0)
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.audioOffsetTime] = setup
        }
    }
    
    var speed: Double {
        get {
            return Double(self.player?.rate ?? 0)
        }
        
        set {
            func setup() {
                self.player?.rate = Float(newValue)
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.speed] = setup
        }
    }
    
    var position: Double {
        if self.length == 0 {
            return 0
        }
        return self.currentTime / self.length
    }
    
    var length: TimeInterval {
        let length = self.player?.media?.length.value?.doubleValue ?? 0
        return length / 1000
    }
    
    var currentTime: TimeInterval {
        let time = self.player?.time.value?.doubleValue ?? 0
        return time / 1000
    }
    
    var isPlaying: Bool {
        return self.player?.isPlaying ?? false
    }
    
    /// 10 .. 120
    var fontSize: Float? {
        didSet {
            func setup() {
                if let fontSize = self.fontSize {
                    let anxFontSizeRange: (min: Float, max: Float) = (min: 10, max: 120)
                    let vlcFontSizeRange: (min: Float, max: Float) = (min: 0.1, max: 5) // vlc的区间为 0.1~5
                    
                    let vlcFontSize = vlcFontSizeRange.min + ((fontSize - anxFontSizeRange.min) * (vlcFontSizeRange.max - vlcFontSizeRange.min) / (anxFontSizeRange.max - anxFontSizeRange.min))
                    self.player?.anx_setTextRendererFontSize(vlcFontSize as NSNumber)
                }
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.subtitleFontSize] = setup
        }
    }
    
    var fontName: String? {
        didSet {
            
            func setup() {
                if let fontName = self.fontName {
                    self.player?.anx_setTextRendererFont(fontName)
                }
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.subtitleFontName] = setup
        }
    }
    
    var fontColor: ANXColor? {
        didSet {
            if let fontColor = self.fontColor {
                self.player?.anx_setTextRendererFontColor(fontColor.rgbValue() as NSNumber)
            }
        }
    }
    
    var audioChannelList: [AudioChannelProtocol] {
        return self.player?.audioTracks ?? []
    }
    
    var currentAudioChannel: AudioChannelProtocol? {
        get {
            
            return self.player?.audioTracks.first { track in
                return track.isSelected
            }
        }
        
        set {
            func setup() {
                if let sub = newValue as? VLCMediaPlayer.Track {
                    if let firstIndex = player?.textTracks.firstIndex(where: { track in
                        return track.trackId == sub.trackId
                    }) {
                        self.player?.selectTrack(at: firstIndex, type: .audio)
                    }
                } else {
                    self.player?.selectTrack(at: -1, type: .audio)
                }
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.currentAudioChannel] = setup
        }
    }
    
    var timeChangedCallBack: ((MediaPlayerProtocol, Double) -> Void)?
    
    var stateChangedCallBack: ((MediaPlayerProtocol, PlayerState) -> Void)?
    
    var bufferInfoDidChangeCallBack: ((MediaPlayerProtocol, File, MediaBufferInfo) -> Void)?
    
    var aspectRatio: PlayerAspectRatio {
        get {
            if let videoAspectRatio = self.player?.videoAspectRatio {
                return PlayerAspectRatio(rawValue: videoAspectRatio) ?? .default
            }
            return .default
        }
        
        set {
            func setup() {
                switch newValue {
                case .default:
                    self.player?.scaleFactor = 0
                    self.player?.videoAspectRatio = nil
                case .fillToScreen:
                    if let window = self.mediaView.window {
                        self.player?.videoAspectRatio = nil
                        
                        var windowSize = window.frame.size
                        var videoSize = self.player?.videoSize ?? .zero
                        
                        if videoSize == .zero {
                            videoSize = .init(width: 1, height: 1)
                        }
                        
                        if windowSize == .zero {
                            windowSize = .init(width: 1, height: 1)
                        }
                        
                        let ar = videoSize.width / videoSize.height
                        let dar = windowSize.width / windowSize.height
                        
                        let scale: CGFloat
                        
                        if (dar >= ar) {
                            scale = windowSize.width / videoSize.width;
                        } else {
                            scale = windowSize.height / videoSize.height;
                        }
                        
                        let windowScale: CGFloat
                        
                        #if os(iOS)
                        windowScale = window.contentScaleFactor
                        #else
                        windowScale = window.backingScaleFactor
                        #endif
                        
                        self.player?.scaleFactor = Float(scale * windowScale)
                    }
                
                case .fourToThree, .sixteenToNine, .sixteenToTen, .other(_, _):
                    self.player?.scaleFactor = 0
                    self.player?.videoAspectRatio = newValue.rawValue
                }
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.aspectRatio] = setup
        }
    }
    
    var state: PlayerState {
        switch self.player?.state {
        case .stopped:
            return .stop
        case .paused:
            return .pause
        case .playing:
            return .playing
        case .buffering:
            if self.timeIsUpdate {
                return .playing
            } else {
                return .pause
            }
        default:
            return .pause
        }
    }
    
    func setPosition(_ position: Double) {
        let position = max(min(position, 1), 0)
        self.player?.position = position
    }
    
    func play(_ media: File) {
        self.currentPlayItem = media
        self.player?.play()
    }
    
    func play() {
        self.player?.play()
    }
    
    func pause() {
        self.player?.pause()
    }
    
    func stop() {
        self.player?.stop()
    }
    
    func isEndPosition(_ position: Double) -> Bool {
        return position >= self.endFlagProgress
    }
    
    deinit {
        self.playerTimer?.invalidate()
    }
    
    //MARK: Private Method
    
    private func reloadOptionAndCreatePlayer() {
        guard let item = self.currentPlayItem else { return }
        
        let position = self.position
        
        self.player = self.createPlayerInstance()
        for (_, initAction) in self.initActionDic {
            initAction()
        }
        self.play(item)
        self.setPosition(position)
    }
    
    private func createPlayerInstance() -> VLCMediaPlayer {
        let options = self.mediaOptionsDic.compactMap { option in
            return "\(option.key.rawValue)=\(option.value)"
        }
        
        let player = VLCMediaPlayer(options: options)
        player.drawable = self.mediaView
        player.delegate = self
        
        return player
    }
    
}

extension VLCPlayerWarrper: FileDelegate {
    
    func mediaBufferDidChange(file: File, bufferInfo: MediaBufferInfo) {
        DispatchQueue.main.async {
            if file.url != self.currentPlayItem?.url {
                return
            }
            
            self.bufferInfoDidChangeCallBack?(self, file, bufferInfo)
        }
    }
}

extension VLCPlayerWarrper: VLCMediaPlayerDelegate {
    
    func mediaPlayerTrackAdded(_ trackId: String, with trackType: VLCMedia.TrackType) {
        ANX.logInfo(.player, "加载轨道 trackType: \(trackType), trackId:\(trackId)")
        
        if trackType == .text {
            let textTrack = self.player?.textTracks.first { track in
                return track.trackId == trackId
            }
            
            if let currentTask = self.subtitleTaskQueue.currentTask, textTrack?.isExternalSubtitle == true {
                currentTask.completion(trackId: trackId)
            }
        }
    }
    
    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        
        DispatchQueue.main.async {
            let nowTime = self.currentTime
            let length = self.length
            
            let position = length > 0 ? nowTime / length : 0
            
            self.timeChangedCallBack?(self, position)
            self.playerTimer?.invalidate()
            self.playerTimer = Timer.mp_scheduledTimer(timeInterval: 1, repeats: false) { [weak self] (aTimer) in
                guard let self = self else { return }
                
                self.timeIsUpdate = false
                self.stateChangedCallBack?(self, self.state)
            }
            
            if self.timeIsUpdate == false {
                self.timeIsUpdate = true
                self.stateChangedCallBack?(self, self.state)
            }
            
            self.timeChangedCallBack?(self, self.position)
        }
        
    }
    
    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        self.stateChangedCallBack?(self, self.state)
    }
}
