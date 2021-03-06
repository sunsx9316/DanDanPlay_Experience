//
//  MediaPlayer.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/1/14.
//

import Foundation

extension Timer {
    open class func mp_scheduledTimer(timeInterval ti: TimeInterval, repeats yesOrNo: Bool, action: @escaping((Timer) -> Void)) -> Timer {
        return Timer.scheduledTimer(timeInterval: ti, target: self, selector: #selector(mp_timerStart(_:)), userInfo: action, repeats: yesOrNo)
    }
    
    @objc private class func mp_timerStart(_ sender: Timer) {
        let action = sender.userInfo as? (Timer) -> Void
        action?(sender)
    }
}

#if os(iOS)
import UIKit
import MobileVLCKit
import AVFoundation
public typealias MediaView = UIView
#else
import AppKit
import VLCKit
public typealias MediaView = NSView
#endif

public protocol MediaPlayerDelegate: class {
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval)
    func player(_ player: MediaPlayer, stateDidChange state: MediaPlayer.State)
    func player(_ player: MediaPlayer, mediaDidChange media: File?)
}

public extension MediaPlayerDelegate {
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {}
    func player(_ player: MediaPlayer, stateDidChange state: MediaPlayer.State) {}
    func player(_ player: MediaPlayer, mediaDidChange media: File?) {}
}

open class MediaPlayer: NSObject {
    
    public enum PlayMode {
        case playOnce
        case autoPlayNext
        case repeatCurrentItem
        case repeatList
    }
    
    public enum State {
        case playing
        case pause
        case stop
    }
    
    public struct Subtitle {
        public let index: Int
        public let name: String
    }
    
    public struct AudioChannel {
        public let index: Int
        public let name: String
    }
    
    public enum AspectRatio: RawRepresentable {
        public typealias RawValue = String
        
        case `default`
        case fillToScreen
        case fourToThree
        case sixteenToNine
        case sixteenToTen
        case other(_ width: Int, _ height: Int)
        
        public init?(rawValue: RawValue) {
            switch rawValue {
            case "DEFAULT":
                self = .default
            case "FILL_TO_SCREEN":
                self = .fillToScreen
            case "4:3":
                self = .fourToThree
            case "16:9":
                self = .sixteenToNine
            case "16:10":
                self = .sixteenToTen
            default:
                let arr = rawValue.components(separatedBy: ":")
                if arr.count < 2 {
                    return nil
                }
                
                let width = Int(arr[0]) ?? 0
                let height = Int(arr[1]) ?? 0
                self = .other(width, height)
            }
        }
        
        public var rawValue: RawValue {
            switch self {
            case .default:
                return "DEFAULT"
            case .fillToScreen:
                return "FILL_TO_SCREEN"
            case .fourToThree:
                return "4:3"
            case .sixteenToNine:
                return "16:9"
            case .sixteenToTen:
                return "16:10"
            case .other(let width, let height):
                return "\(width):\(height)"
            }
        }
    }
    
    open private(set) lazy var mediaView = MediaView()
    
    open private(set) lazy var playList = [File]()
    
    open private(set) var currentPlayItem: File? {
        didSet {
            if let item = self.currentPlayItem {
                self.player.stop()
                self.player.media = VLCMedia(url: item.url)
            }
            
            self.delegate?.player(self, mediaDidChange: self.currentPlayItem)
        }
    }
    
    open var subtitleList: [Subtitle] {
        return self.player.videoSubTitlesIndexes.indices.compactMap({ subtitleWithIndexInPlayer($0) })
    }
    
    open var currentSubtitle: Subtitle? {
        get {
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
            if let subtitle = newValue {
                self.player.currentVideoSubTitleIndex = Int32(subtitle.index)
            } else {
                self.player.currentVideoSubTitleIndex = -1
            }
        }
    }
    
    open var audioChannelList: [AudioChannel] {
        return self.player.audioTrackIndexes.indices.compactMap({ audioChannelWithIndexInPlayer($0) })
    }
    
    open var currentAudioChannel: AudioChannel?  {
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
    
    private lazy var player: VLCMediaPlayer = {
        var player = VLCMediaPlayer()
        player.drawable = self.mediaView
        player.delegate = self
        return player
    }()
    
    open var playMode = PlayMode.autoPlayNext
    open var volume: Int {
        get {
            return Int(self.player.audio.volume)
        }
        
        set {
            self.player.audio.volume = Int32(newValue)
        }
    }
    
    open var subtitleDelay: CGFloat {
        get {
            return CGFloat(self.player.currentVideoSubTitleDelay) / 1000000.0
        }
        
        set {
            self.player.currentVideoSubTitleDelay = Int(newValue * 1000000.0)
        }
    }
    
    open var speed: CGFloat {
        get {
            return CGFloat(self.player.rate)
        }
        
        set {
            self.player.rate = Float(newValue)
        }
    }
    
    open var aspectRatio: AspectRatio {
        get {
            let str = String(cString: self.player.videoAspectRatio)
            return AspectRatio(rawValue: str) ?? .default
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
    
    open var position: CGFloat {
        return CGFloat(self.player.position)
    }
    
    open var length: TimeInterval {
        let length = self.player.media.length.value?.doubleValue ?? 0
        return length / 1000
    }
    
    open var currentTime: TimeInterval {
        let time = self.player.time.value?.doubleValue ?? 0
        return time / 1000
    }
    
    open var state: State {
        switch self.player.state {
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
    
    open var isPlaying: Bool {
        return self.player.isPlaying
    }
    
    open weak var delegate: MediaPlayerDelegate?
    
    private var playerTimer: Timer?
    private var timeIsUpdate = false
    
    public override init() {
        super.init()
        
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterreption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.playerTimer?.invalidate()
        self.player.stop()
    }
    
    open func setPosition(_ position: CGFloat) -> TimeInterval {
        let p = max(min(position, 1), 0)
        
        self.player.position = Float(p)
        return self.length * TimeInterval(position)
    }
    
    open func play(_ media: File) {
        
        if !self.playList.contains(where: { $0.url == media.url }) {
            self.playList.append(media)
        }
        
        if self.currentPlayItem?.url != media.url {
            self.currentPlayItem = media
        }
        
        self.player.play()
    }
    
    open func play() {
        self.player.play()
    }
    
    open func pause() {
        self.player.pause()
    }
    
    open func stop() {
        self.currentPlayItem = nil
        self.player.stop()
    }
    
    open func openVideoSubTitle(with url: URL) {
        self.player.addPlaybackSlave(url, type: .subtitle, enforce: true)
    }
    
    open func addMediaToPlayList(_ media: File) {
        if !self.playList.contains(where: { $0.url == media.url }) {
            self.playList.append(media)
        }
    }
    
    open func removeMediaFromPlayList(_ media: File) {
        self.playList.removeAll(where: { $0.url == media.url })
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
    
    #if os(iOS)
    @objc private func handleInterreption(_ notice: Notification) {
        guard let interruptionType = notice.userInfo?[AVAudioSessionInterruptionTypeKey] as? AVAudioSession.InterruptionType else { return }
        
        switch interruptionType {
        case .began:
            if self.isPlaying {
                self.pause()
            }
        default:
            break
        }
    }
    #endif
}

extension MediaPlayer: VLCMediaPlayerDelegate {
    public func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        let nowTime = self.currentTime
        let length = self.length
        
        self.delegate?.player(self, currentTime: nowTime, totalTime: length)
        self.playerTimer?.invalidate()
        self.playerTimer = Timer.mp_scheduledTimer(timeInterval: 1, repeats: false) { [weak self] (aTimer) in
            guard let self = self else { return }
            
            self.timeIsUpdate = false
            self.stateChanged()
        }
        
        if self.timeIsUpdate == false {
            self.timeIsUpdate = true
            self.stateChanged()
        }
    }
    
    public func mediaPlayerStateChanged(_ aNotification: Notification!) {
        stateChanged()
    }
    
    private func stateChanged() {
        self.delegate?.player(self, stateDidChange: self.state)
        if self.isPlayAtEnd() {
            self.tryPlayNextItem()
        }
    }
    
    private func isPlayAtEnd() -> Bool {
        return self.position >= 0.999
    }
    
    private func tryPlayNextItem() {
        
        func nextItemWithCycle(_ cycle: Bool) -> File? {
            if let index = self.playList.firstIndex(where: { $0.url == self.currentPlayItem?.url }) {
                if index == self.playList.count - 1 {
                    return cycle ? self.playList.first : nil
                }
                return self.playList[index + 1]
            }
            return nil
        }
        
        switch self.playMode {
        case .playOnce:
            break
        case .autoPlayNext:
            if isPlayAtEnd() {
                self.stop()
                if let nextItem = nextItemWithCycle(false) {
                    self.play(nextItem)
                }
            }
        case .repeatCurrentItem:
            if isPlayAtEnd() {
                self.stop()
                if let currentPlayItem = self.currentPlayItem {
                    self.play(currentPlayItem)                    
                }
            }
        case .repeatList:
            if isPlayAtEnd() {
                self.stop()
                if let nextItem = nextItemWithCycle(true) {
                    self.play(nextItem)
                }
            }
        }
    }
}
