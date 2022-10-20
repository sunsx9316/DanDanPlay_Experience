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
    let index: Int
    
    let name: String
}

/// 外挂字幕
struct ExternalSubtitle: SubtitleProtocol {
    let name: String
    
    let url: URL
}

class VLCPlayerWarrper: NSObject, MediaPlayerProtocol {
    
    fileprivate lazy var player: VLCMediaPlayer = {
        var player = VLCMediaPlayer()
        player.drawable = self.mediaView
        player.delegate = self
        return player
    }()
    
    fileprivate var playerTimer: Timer?
    
    fileprivate var timeIsUpdate = false
    
    private let endFlagProgress = 0.99
    
    /// 当前选择的字幕文件
    private var currentSubTitleFile: SubtitleProtocol?
    
    private var mediaThumbnailer: MediaThumbnailer?
    
    lazy var mediaView: ANXView = ANXView()
    
    var currentPlayItem: File? {
        didSet {
            self.player.stop()
            self.currentSubTitleFile = nil
            let media = self.currentPlayItem?.createMedia(delegate: self)
            self.player.media = media
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
        return self.player.videoSubTitlesIndexes.indices.compactMap({ subtitleWithIndexInPlayer($0) })
    }
    
    var currentSubtitle: SubtitleProtocol? {
        get {
            if let currentSubTitleFile = self.currentSubTitleFile {
                return currentSubTitleFile
            }
            
            let currentVideoSubTitleIndex = self.player.currentVideoSubTitleIndex
            if let fristIndex = self.player.videoSubTitlesIndexes.firstIndex(where: { (value) -> Bool in
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
            
            if let sub = newValue as? Subtitle {
                self.player.currentVideoSubTitleIndex = Int32(sub.index)
            } else if let sub = newValue as? ExternalSubtitle {
                ANX.logInfo(.subtitle, "加载外部字幕 url: \(sub.url)")
                self.player.addPlaybackSlave(sub.url, type: .subtitle, enforce: true)
            }
        }
    }
    
    var volume: Int {
        get {
            return Int(self.player.audio?.volume ?? 0)
        }
        
        set {
            self.player.audio?.volume = Int32(newValue)
        }
    }
    
    var subtitleDelay: Double {
        get {
            return Double(self.player.currentVideoSubTitleDelay) / 1000000.0
        }
        
        set {
            self.player.currentVideoSubTitleDelay = Int(newValue * 1000000.0)
        }
    }
    
    var speed: Double {
        get {
            return Double(self.player.rate)
        }
        
        set {
            self.player.rate = Float(newValue)
        }
    }
    
    var position: Double {
        return Double(self.player.position)
    }
    
    var length: TimeInterval {
        let length = self.player.media?.length.value?.doubleValue ?? 0
        return length / 1000
    }
    
    var currentTime: TimeInterval {
        let time = self.player.time.value?.doubleValue ?? 0
        return time / 1000
    }
    
    var isPlaying: Bool {
        return self.player.isPlaying
    }
    
    var fontSize: Int? {
        didSet {
            if let fontSize = self.fontSize {
                let sel = Selector(("setTextRendererFontSize:"))
                if player.responds(to: sel) {
                    player.perform(sel, with: fontSize)
                }
            }
        }
    }
    
    var fontName: String? {
        didSet {
            if let fontName = self.fontName {
                let sel = Selector(("setTextRendererFont:"))
                player.perform(sel, with: fontName)
            }
        }
    }
    
    var fontColor: ANXColor? {
        didSet {
            if let fontColor = self.fontColor {
                let sel = Selector(("setTextRendererFontColor:"))
                player.perform(sel, with: fontColor.rgbValue)
            }
        }
    }
    
    var audioChannelList: [AudioChannel] {
        return self.player.audioTrackIndexes.indices.compactMap({ audioChannelWithIndexInPlayer($0) })
    }
    
    var currentAudioChannel: AudioChannel? {
        get {
            let currentAudioTrackIndex = self.player.currentAudioTrackIndex
            if let fristIndex = self.player.audioTrackIndexes.firstIndex(where: { (value) -> Bool in
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
            if let audioChannel = newValue {
                self.player.currentAudioTrackIndex = Int32(audioChannel.index)
            } else {
                self.player.currentAudioTrackIndex = -1
            }
        }
    }
    
    var timeChangedCallBack: ((MediaPlayerProtocol, Double) -> Void)?
    
    var stateChangedCallBack: ((MediaPlayerProtocol, PlayerState) -> Void)?
    
    var bufferInfoDidChangeCallBack: ((MediaPlayerProtocol, File, MediaBufferInfo) -> Void)?
    
    var aspectRatio: PlayerAspectRatio {
        get {
            if let videoAspectRatio = self.player.videoAspectRatio {
                let str = String(cString: videoAspectRatio)
                return PlayerAspectRatio(rawValue: str) ?? .default
            }
            return .default
        }
        
        set {
            switch newValue {
            case .default:
                self.player.scaleFactor = 0
                self.player.videoAspectRatio = nil
                self.player.videoCropGeometry = nil
            case .fillToScreen:
                if let window = self.mediaView.window {
                    self.player.videoAspectRatio = nil
                    
                    let windowSize = window.frame.size
                    let videoSize = self.player.videoSize
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
                    
                    self.player.scaleFactor = Float(scale * windowScale)
                }
            
            case .fourToThree, .sixteenToNine, .sixteenToTen, .other(_, _):
                self.player.scaleFactor = 0
                self.player.videoCropGeometry = nil
                self.player.videoAspectRatio = UnsafeMutablePointer(mutating: (newValue.rawValue as NSString).utf8String)
            }
        }
    }
    
    var state: PlayerState {
        switch self.player.state {
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
    
    func setPosition(_ position: Double) -> TimeInterval {
        let position = max(min(position, 1), 0)
        self.player.position = Float(position)
        return self.length * TimeInterval(position)
    }
    
    func play(_ media: File) {
        self.currentPlayItem = media
        self.player.play()
    }
    
    func play() {
        self.player.play()
    }
    
    func pause() {
        self.player.pause()
    }
    
    func stop() {
        self.player.stop()
    }
    
    func isPlayAtEnd() -> Bool {
        return self.position >= self.endFlagProgress
    }
    
    deinit {
        self.playerTimer?.invalidate()
    }
    
    //MARK: Private Method
    private func subtitleWithIndexInPlayer(_ index: Int) -> Subtitle? {
        if index < self.player.videoSubTitlesIndexes.count,
           let indexNumber = self.player.videoSubTitlesIndexes[index] as? Int {
            
            let name: String
            if index < self.player.videoSubTitlesNames.count {
                name = self.player.videoSubTitlesNames[index] as? String ?? "未知名称"
            } else {
                name = "未知名称"
            }
            
            return Subtitle(index: indexNumber, name: name)
        } else {
            return nil
        }
    }
    
    private func audioChannelWithIndexInPlayer(_ index: Int) -> AudioChannel? {
        if index < self.player.audioTrackIndexes.count,
           let indexNumber = self.player.audioTrackIndexes[index] as? Int {
            
            let name: String
            if index < self.player.audioTrackNames.count {
                name = self.player.audioTrackNames[index] as? String ?? "未知名称"
            } else {
                name = "未知名称"
            }
            
            return AudioChannel(index: indexNumber, name: name)
        } else {
            return nil
        }
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
        
        self.timeChangedCallBack?(self, self.position)
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
