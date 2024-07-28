//
//  VLCPlayerWarrper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/10/2.
//

import Foundation
import ANXLog
#if os(iOS)
import MobileVLCKit
import YYCategories
#else
import VLCKit
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
        case subtitleDelay
        case speed
        case currentAudioChannel
        case aspectRatio
    }

    
    private var player: VLCMediaPlayer?
    
    fileprivate var playerTimer: Timer?
    
    fileprivate var timeIsUpdate = false
    
    private let endFlagProgress = 0.99
    
    /// 当前选择的字幕文件
    private var currentSubTitleFile: SubtitleProtocol?
    
    private var mediaThumbnailer: MediaThumbnailer?
    
    lazy var mediaView: ANXView = ANXView()
    
    private lazy var mediaOptionsDic = [Options: Any]()
    
    private lazy var initActionDic = [InitAction: () -> Void]()
    
    var currentPlayItem: File? {
        didSet {
            
            if self.player == nil {
                self.player = self.createPlayerInstance()
                for (_, initAction) in self.initActionDic {
                    initAction()
                }
            }
            
            self.player?.stop()
            self.currentSubTitleFile = nil
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
        return self.player?.videoSubTitlesIndexes.indices.compactMap({ subtitleWithIndexInPlayer($0) }) ?? []
    }
    
    var currentSubtitle: SubtitleProtocol? {
        get {
            
            guard let player = self.player else { return nil }
            
            if let currentSubTitleFile = self.currentSubTitleFile {
                return currentSubTitleFile
            }
            
            let currentVideoSubTitleIndex = player.currentVideoSubTitleIndex
            if let fristIndex = player.videoSubTitlesIndexes.firstIndex(where: { (value) -> Bool in
                if let value = value as? Int, value == currentVideoSubTitleIndex {
                    return true
                }
                return false
            }) {
                return subtitleWithIndexInPlayer(fristIndex)
            }
            return nil
        }
        
        set {
            self.currentSubTitleFile = newValue
            
            func setup() {
                if let sub = newValue as? Subtitle {
                    self.player?.currentVideoSubTitleIndex = Int32(sub.index)
                } else if let sub = newValue as? ExternalSubtitle {
                    ANX.logInfo(.subtitle, "加载外部字幕 url: \(sub.url)")
                    self.player?.addPlaybackSlave(sub.url, type: .subtitle, enforce: true)
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
    
    var subtitleDelay: Double {
        get {
            return Double(self.player?.currentVideoSubTitleDelay ?? 0) / 1000000.0
        }
        
        set {
            func setup() {
                self.player?.currentVideoSubTitleDelay = Int(newValue * 1000000.0)
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.subtitleDelay] = setup
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
    
    /// 10 .. 500
    var fontSize: Float? {
        didSet {
            if let fontSize = self.fontSize {
                self.player?.anx_setTextRendererFontSize(fontSize as NSNumber)
            }
        }
    }
    
    var fontName: String? {
        didSet {
            if let fontName = self.fontName {
                self.player?.anx_setTextRendererFont(fontName)
            }
        }
    }
    
    var fontColor: ANXColor? {
        didSet {
            if let fontColor = self.fontColor {
                self.player?.anx_setTextRendererFontColor(fontColor.rgbValue as NSNumber)
            }
        }
    }
    
    var audioChannelList: [AudioChannelProtocol] {
        return self.player?.audioTrackIndexes.indices.compactMap({ audioChannelWithIndexInPlayer($0) }) ?? []
    }
    
    var currentAudioChannel: AudioChannelProtocol? {
        get {
            guard let player = self.player else { return nil }
            
            let currentAudioTrackIndex = player.currentAudioTrackIndex
            if let fristIndex = player.audioTrackIndexes.firstIndex(where: { (value) -> Bool in
                if let value = value as? Int, value == currentAudioTrackIndex {
                    return true
                }
                return false
            }) {
                return audioChannelWithIndexInPlayer(fristIndex)
            }
            return nil
        }
        
        set {
            func setup() {
                if let audioChannel = newValue {
                    self.player?.currentAudioTrackIndex = audioChannel.audioId
                } else {
                    self.player?.currentAudioTrackIndex = -1
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
    
    var positionChangedCallBack: ((any MediaPlayerProtocol, Double, Double) -> Void)?
    
    var aspectRatio: PlayerAspectRatio {
        get {
            if let videoAspectRatio = self.player?.videoAspectRatio {
                let str = String(cString: videoAspectRatio)
                return PlayerAspectRatio(rawValue: str) ?? .default
            }
            return .default
        }
        
        set {
            func setup() {
                switch newValue {
                case .default:
                    self.player?.scaleFactor = 0
                    self.player?.videoAspectRatio = nil
                    self.player?.videoCropGeometry = nil
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
                    self.player?.videoCropGeometry = nil
                    self.player?.videoAspectRatio = UnsafeMutablePointer(mutating: (newValue.rawValue as NSString).utf8String)
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
        case .playing, .esAdded:
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
        self.player?.position = Float(position)
        self.positionChangedCallBack?(self, position, self.length * TimeInterval(position))
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
    private func subtitleWithIndexInPlayer(_ index: Int) -> Subtitle? {
        guard let player = self.player else { return nil }
        
        if index < player.videoSubTitlesIndexes.count,
           let indexNumber = player.videoSubTitlesIndexes[index] as? Int {
            
            let name: String
            if index < player.videoSubTitlesNames.count {
                name = player.videoSubTitlesNames[index] as? String ?? "未知名称"
            } else {
                name = "未知名称"
            }
            
            return Subtitle(subtitleName: name, index: indexNumber)
        } else {
            return nil
        }
    }
    
    private func audioChannelWithIndexInPlayer(_ index: Int) -> AudioChannelProtocol? {
        guard let player = self.player else { return nil }
        
        if index < player.audioTrackIndexes.count,
           let indexNumber = player.audioTrackIndexes[index] as? Int32 {
            
            let name: String
            if index < player.audioTrackNames.count {
                name = player.audioTrackNames[index] as? String ?? "未知名称"
            } else {
                name = "未知名称"
            }
            
            return AudioChannel(audioName: name, audioId: indexNumber)
        } else {
            return nil
        }
    }
    
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
    
    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        
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
    
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        self.stateChangedCallBack?(self, self.state)
    }
}
