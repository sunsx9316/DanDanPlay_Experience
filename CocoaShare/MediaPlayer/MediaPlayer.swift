//
//  MediaPlayer.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/1/14.
//

import Foundation

fileprivate extension Timer {
    class func mp_scheduledTimer(timeInterval ti: TimeInterval, repeats yesOrNo: Bool, action: @escaping((Timer) -> Void)) -> Timer {
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
typealias MediaView = UIView
#else
import AppKit
import VLCKit
typealias MediaView = NSView
#endif

protocol MediaPlayerDelegate: AnyObject {
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval)
    func player(_ player: MediaPlayer, stateDidChange state: MediaPlayer.State)
    func player(_ player: MediaPlayer, shouldChangeMedia media: File) -> Bool
}

extension MediaPlayerDelegate {
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {}
    func player(_ player: MediaPlayer, stateDidChange state: MediaPlayer.State) {}
    func player(_ player: MediaPlayer, shouldChangeMedia media: File) -> Bool { return true }
}

private class Coordinator: NSObject {
    weak var player: MediaPlayer?
    
    init(player: MediaPlayer) {
        super.init()
        self.player = player
    }
}

class MediaPlayer {
    
    enum PlayMode {
        case playOnce
        case autoPlayNext
        case repeatCurrentItem
        case repeatList
    }
    
    enum State {
        case playing
        case pause
        case stop
    }
    
    struct Subtitle {
        let index: Int
        let name: String
    }
    
    struct AudioChannel {
        let index: Int
        let name: String
    }
    
    enum AspectRatio: RawRepresentable {
        typealias RawValue = String
        
        case `default`
        case fillToScreen
        case fourToThree
        case sixteenToNine
        case sixteenToTen
        case other(_ width: Int, _ height: Int)
        
        init?(rawValue: RawValue) {
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
        
        var rawValue: RawValue {
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
    
    private(set) lazy var mediaView = MediaView()
    
    private(set) lazy var playList = [File]()
    
    private let endFlagProgress = 0.99
    
    private(set) var currentPlayItem: File? {
        didSet {
            self.player.stop()
            let media = self.currentPlayItem?.createMedia()
            self.player.media = media
        }
    }
    
    private lazy var coordinator: Coordinator = {
        return Coordinator(player: self)
    }()
    
    var subtitleList: [Subtitle] {
        return self.player.videoSubTitlesIndexes.indices.compactMap({ subtitleWithIndexInPlayer($0) })
    }
    
    var currentSubtitle: Subtitle? {
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
    
    var audioChannelList: [AudioChannel] {
        return self.player.audioTrackIndexes.indices.compactMap({ audioChannelWithIndexInPlayer($0) })
    }
    
    var currentAudioChannel: AudioChannel?  {
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
    
    fileprivate lazy var player: VLCMediaPlayer = {
        var player = VLCMediaPlayer()
        player.drawable = self.mediaView
        player.delegate = self.coordinator
        return player
    }()
    
    var playMode = PlayMode.autoPlayNext
    var volume: Int {
        get {
            return Int(self.player.audio.volume)
        }
        
        set {
            self.player.audio.volume = Int32(newValue)
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
    
    var aspectRatio: AspectRatio {
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
    
    var position: Double {
        return Double(self.player.position)
    }
    
    var length: TimeInterval {
        let length = self.player.media.length.value?.doubleValue ?? 0
        return length / 1000
    }
    
    var currentTime: TimeInterval {
        let time = self.player.time.value?.doubleValue ?? 0
        return time / 1000
    }
    
    var state: State {
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
    
    var isPlaying: Bool {
        return self.player.isPlaying
    }
    
    /// 字体大小 值越大 字体越小
    var fontSize: Int? {
        didSet {
            if let fontSize = self.fontSize {
                let sel = Selector(("setTextRendererFontSize:"))
                player.perform(sel, with: fontSize)
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
    
    var fontColor: UIColor? {
        didSet {
            if let fontColor = self.fontColor {
                let sel = Selector(("setTextRendererFontColor:"))
                player.perform(sel, with: fontColor.rgbValue)
            }
        }
    }
    
    weak var delegate: MediaPlayerDelegate?
    
    fileprivate var playerTimer: Timer?
    fileprivate var timeIsUpdate = false
    
    init() {
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterreption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        #endif
        
        self.setupInit()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.playerTimer?.invalidate()
        self.player.stop()
        debugPrint("player deinit")
    }
    
    func setPosition(_ position: Double) -> TimeInterval {
        let position = max(min(position, 1), 0)
        self.player.position = Float(position)
        if position > self.endFlagProgress {
            self.tryPlayNextItem()
        }
        return self.length * TimeInterval(position)
    }
    
    func play(_ media: File) {
        
        if !self.playList.contains(where: { $0.url == media.url }) {
            self.playList.append(media)
        }
        
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
    
    func openVideoSubTitle(with url: URL) {
        self.player.addPlaybackSlave(url, type: .subtitle, enforce: true)
    }
    
    func addMediaToPlayList(_ media: File) {
        if !self.playList.contains(where: { $0.url == media.url }) {
            self.playList.append(media)
        }
    }
    
    func removeMediaFromPlayList(_ media: File) {
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
    
    //MARK: Private Method
    private func setupInit() {
        self.fontSize = 20
    }
    
    fileprivate func stateChanged() {
        self.delegate?.player(self, stateDidChange: self.state)
        if self.isPlayAtEnd() {
            self.tryPlayNextItem()
        }
    }
    
    private func isPlayAtEnd() -> Bool {
        return self.position >= self.endFlagProgress
    }
    
    private func changeCurrentItem(_ item: File) -> Bool {
        let shouldChangeMedia = self.delegate?.player(self, shouldChangeMedia: item) == true
        if shouldChangeMedia {
            self.currentPlayItem = item
        }
        return shouldChangeMedia
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
            if let nextItem = nextItemWithCycle(false) {
                if self.changeCurrentItem(nextItem) {
                    self.play(nextItem)
                }
            }
        case .repeatCurrentItem:
            if let currentPlayItem = self.currentPlayItem {
                if self.changeCurrentItem(currentPlayItem) {
                    self.play(currentPlayItem)
                }
            }
        case .repeatList:
            if let nextItem = nextItemWithCycle(true) {
                if self.changeCurrentItem(nextItem) {
                    self.play(nextItem)
                }
            }
        }
    }
}

extension Coordinator: VLCMediaPlayerDelegate {
    
    private func playerTimerUpdate() {
        self.player?.timeIsUpdate = false
        self.player?.stateChanged()
    }
    
    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        
        guard let player = self.player else { return }
        
        let nowTime = player.currentTime
        let length = player.length
        
        player.delegate?.player(player, currentTime: nowTime, totalTime: length)
        player.playerTimer?.invalidate()
        player.playerTimer = Timer.mp_scheduledTimer(timeInterval: 1, repeats: false) { [weak self] (aTimer) in
            guard let self = self else { return }
            
            self.playerTimerUpdate()
        }
        
        if player.timeIsUpdate == false {
            player.timeIsUpdate = true
            player.stateChanged()
        }
        
    }
    
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        guard let player = self.player else { return }
        
        player.stateChanged()
        debugPrint("mediaPlayerStateChanged \(VLCMediaPlayerStateToString(player.player.state))")
    }
}
