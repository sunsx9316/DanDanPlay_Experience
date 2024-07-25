//
//  MediaPlayer.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/1/14.
//

import Foundation
import ANXLog
#if os(iOS)
import AVFoundation
#endif

protocol MediaPlayerDelegate: AnyObject {
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval)
    func player(_ player: MediaPlayer, stateDidChange state: PlayerState)
    func player(_ player: MediaPlayer, shouldChangeMedia media: File) -> Bool
    func player(_ player: MediaPlayer, file: File, bufferInfoDidChange bufferInfo: MediaBufferInfo)
    func playerListDidChange(_ player: MediaPlayer)
    func player(_ player: MediaPlayer, didChangePosition: Double, mediaTime: TimeInterval)
}

protocol SubtitleProtocol {
    var name: String { get }
}

extension MediaPlayerDelegate {
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {}
    func player(_ player: MediaPlayer, stateDidChange state: PlayerState) {}
    func player(_ player: MediaPlayer, shouldChangeMedia media: File) -> Bool { return true }
    func player(_ player: MediaPlayer, file: File, bufferInfoDidChange bufferInfo: MediaBufferInfo) {}
    func playerListDidChange(_ player: MediaPlayer) {}
}


protocol MediaPlayerProtocol: AnyObject {
    
    var mediaView: ANXView { get }
    
    var currentPlayItem: File? { set get }
    
    var subtitleList: [SubtitleProtocol] { get }
    
    var currentSubtitle: SubtitleProtocol? { set get }
    
    var audioChannelList: [AudioChannel] { get }
    
    var currentAudioChannel: AudioChannel?  { set get }
    
    var timeChangedCallBack: ((MediaPlayerProtocol, Double) -> Void)? { set get }
    
    var stateChangedCallBack: ((MediaPlayerProtocol, PlayerState) -> Void)? { set get }
    
    var bufferInfoDidChangeCallBack: ((MediaPlayerProtocol, File, MediaBufferInfo) -> Void)? { set get }
    
    var positionChangedCallBack: ((MediaPlayerProtocol, Double, Double) -> Void)? { set get }
    
    var volume: Int { set get }
    
    var subtitleDelay: Double { set get }
    
    var speed: Double { set get }
    
    var aspectRatio: PlayerAspectRatio { set get }
    
    var subtitleMargin: Int { set get }
    
    var position: Double { get }
    
    var length: TimeInterval { get }
    
    var currentTime: TimeInterval { get }
    
    var state: PlayerState { get }
    
    var isPlaying: Bool { get }
    
    /// 字体大小 值越大 字体越小
    var fontSize: Int? { set get }
    
    var fontName: String? { set get }
    
    var fontColor: ANXColor? { set get }
    
    func setPosition(_ position: Double)
    
    func play(_ media: File)
    
    func play()
    
    func pause()
    
    func stop()
    
    func isPlayAtEnd() -> Bool
}

enum PlayerMode {
    case playOnce
    case autoPlayNext
    case repeatCurrentItem
    case repeatList
}

enum PlayerState {
    case playing
    case pause
    case stop
}

struct AudioChannel {
    let index: Int
    let name: String
}

enum PlayerAspectRatio: RawRepresentable {
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

class MediaPlayer {
    
    enum CoreType {
        case vlc
        case mpv
    }
    
    private let coreType: CoreType
    
    private(set) lazy var playList = [File]()
    
    private(set) var currentPlayItem: File? {
        get {
            return self.player.currentPlayItem
        }
        
        set {
            self.player.currentPlayItem = newValue
        }
    }

    private let player: MediaPlayerProtocol
    
    var subtitleList: [SubtitleProtocol] {
        return self.player.subtitleList
    }
    
    var currentSubtitle: SubtitleProtocol? {
        get {
            return self.player.currentSubtitle
        }
        
        set {
            self.player.currentSubtitle = newValue
        }
    }
    
    var audioChannelList: [AudioChannel] {
        return self.player.audioChannelList
    }
    
    var currentAudioChannel: AudioChannel?  {
        get {
            return self.player.currentAudioChannel
        }
        
        set {
            self.player.currentAudioChannel = newValue
        }
    }
    
    var playMode = PlayerMode.autoPlayNext
    
    var subtitleMargin: Int  {
        get {
            return self.player.subtitleMargin
        }
        
        set {
            self.player.subtitleMargin = newValue
        }
    }
    
    var volume: Int {
        get {
            return self.player.volume
        }
        
        set {
            self.player.volume = newValue
        }
    }
    
    var subtitleDelay: Double {
        get {
            return self.player.subtitleDelay
        }
        
        set {
            self.player.subtitleDelay = newValue
        }
    }
    
    var speed: Double {
        get {
            return self.player.speed
        }
        
        set {
            self.player.speed = newValue
        }
    }
    
    var aspectRatio: PlayerAspectRatio {
        get {
            return self.player.aspectRatio
        }
        
        set {
            self.player.aspectRatio = newValue
        }
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
    
    var state: PlayerState {
        return self.player.state
    }
    
    var isPlaying: Bool {
        return self.player.isPlaying
    }
    
    /// 字体大小 值越大 字体越小
    var fontSize: Int? {
        set {
            self.player.fontSize = newValue
        }
        
        get {
            return self.player.fontSize
        }
    }
    
    var fontName: String? {
        set {
            self.player.fontName = newValue
        }
        
        get {
            return self.player.fontName
        }
    }
    
    var fontColor: ANXColor? {
        set {
            self.player.fontColor = newValue
        }
        
        get {
            return self.player.fontColor
        }
    }
    
    var mediaView: ANXView {
        return self.player.mediaView
    }
    
    weak var delegate: MediaPlayerDelegate?
    
    init(coreType: CoreType) {
        self.coreType = coreType
        switch coreType {
        case .vlc:
            self.player = VLCPlayerWarrper()
        case .mpv:
            fatalError("暂未支持的内核类型")
        }
        self.setupInit()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.player.stop()
        debugPrint("player deinit")
    }
    
    func setPosition(_ position: Double) {
        self.player.setPosition(position)
        if self.player.isPlayAtEnd() {
            self.tryPlayNextItem()
        }
    }
    
    func play(_ media: File) {

        self.addMediaToPlayList(media)
        self.player.play(media)
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
    
    func addMediaToPlayList(_ media: File) {
        if !self.playList.contains(where: { $0.url == media.url }) {
            self.playList.append(media)
            self.delegate?.playerListDidChange(self)
        }
    }
    
    func removeMediaFromPlayList(_ media: File) {
        self.playList.removeAll(where: { $0.url == media.url })
        self.delegate?.playerListDidChange(self)
    }
    
    //MARK: Private Method
    
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
#if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterreption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
#endif
        
        self.player.stateChangedCallBack = { [weak self] (ins, newState) in
            guard let self = self else { return }
            
            self.delegate?.player(self, stateDidChange: newState)
            if ins.isPlayAtEnd() {
                self.tryPlayNextItem()
            }
        }
        
        self.player.bufferInfoDidChangeCallBack = { [weak self] (ins, file, bufferInfo) in
            guard let self = self else { return }
            
            self.delegate?.player(self, file: file, bufferInfoDidChange: bufferInfo)
        }
        
        self.player.timeChangedCallBack = { [weak self] (ins, time) in
            guard let self = self else { return }
            
            self.delegate?.player(self, currentTime: self.currentTime, totalTime: self.length)
        }
        
        self.player.positionChangedCallBack = { [weak self] (_, position, time) in
            guard let self = self else { return }
            
            self.delegate?.player(self, didChangePosition: position, mediaTime: time)
        }
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
