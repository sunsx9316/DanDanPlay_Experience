//
//  MediaPlayer.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/1/14.
//

import Foundation
#if !os(tvOS)
import ANXLog
#endif
#if os(iOS) || os(tvOS)
import AVFoundation
#endif

protocol MediaPlayerDelegate: AnyObject {
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval)
    func player(_ player: MediaPlayer, stateDidChange state: PlayerState)
    func player(_ player: MediaPlayer, shouldChangeMedia media: File) -> Bool
    func player(_ player: MediaPlayer, file: File, bufferInfoDidChange bufferInfo: MediaBufferInfo)
    func playerListDidChange(_ player: MediaPlayer)
}


protocol MediaPlayerProtocol: AnyObject {
    
    var mediaView: ANXView { get }
    
    var currentPlayItem: File? { set get }
    
    var subtitleList: [SubtitleProtocol] { get }
    
    var currentSubtitle: SubtitleProtocol? { set get }
    
    var audioChannelList: [AudioChannelProtocol] { get }
    
    var currentAudioChannel: AudioChannelProtocol?  { set get }
    
    var timeChangedCallBack: ((MediaPlayerProtocol, Double) -> Void)? { set get }
    
    var stateChangedCallBack: ((MediaPlayerProtocol, PlayerState) -> Void)? { set get }
    
    var endOfFileCallBack: ((MediaPlayerProtocol) -> Void)? { set get }
    
    var bufferInfoDidChangeCallBack: ((MediaPlayerProtocol, File, MediaBufferInfo) -> Void)? { set get }
    
    var volume: Int { set get }
    
    var subtitleOffsetTime: Double { set get }
    
    var subtitleStyle: Bool { set get }
    
    var audioOffsetTime: Double { set get }
    
    var speed: Double { set get }
    
    var aspectRatio: PlayerAspectRatio { set get }
    
    var subtitleYPosition: Float { set get }
    
    var position: Double { get }
    
    var length: TimeInterval { get }
    
    var currentTime: TimeInterval { get }
    
    var state: PlayerState { get }
    
    var isPlaying: Bool { get }
    
    var fontSize: Float? { set get }
    
    var fontName: String? { set get }
    
    var fontColor: ANXColor? { set get }
    
    func setPosition(_ position: Double)
    
    func play(_ media: File)
    
    func play()
    
    func pause()
    
    func stop()
    
    func terminate()
}

enum PlayerMode: Int, CaseIterable {
    case playOnce
    case repeatCurrentItem
    case autoPlayNext
    case repeatList
    
    var title: String {
        switch self {
        case .playOnce:
            return NSLocalizedString("无", comment: "")
        case .repeatCurrentItem:
            return NSLocalizedString("重复播放当前视频", comment: "")
        case .repeatList:
            return NSLocalizedString("自动播放（列表循环）", comment: "")
        case .autoPlayNext:
            return NSLocalizedString("自动播放（不循环）", comment: "")
        }
    }
}

enum PlayerState {
    case playing
    case pause
    case stop
}

protocol SubtitleProtocol {
    var subtitleName: String { get }
}

protocol AudioChannelProtocol {
    var audioName: String { get }
    var audioId: Int64 { get }
}

enum PlayerAspectRatio: RawRepresentable {
    typealias RawValue = String
    
    case `default`
    case fillToScreen
    case fourToThree
    case sixteenToNine
    case sixteenToTen
    
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
            self = .default
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
        }
    }
}

class MediaPlayer {

    enum CoreType: Int {
        case vlc = 0
#if os(iOS) || os(tvOS)
        case mpv = 1
#endif

        var displayName: String {
            switch self {
            case .vlc: return "VLC"
#if os(iOS) || os(tvOS)
            case .mpv: return "MPV"
#endif
            }
        }

        static var allCoreType: [CoreType] {
#if os(iOS) || os(tvOS)
            if #available(iOS 14, tvOS 14, *) {
                return [.mpv, .vlc]
            } else {
                return [.vlc]
            }
#else
            return [.vlc]
#endif
        }
    }

    let coreType: CoreType

    /// 底层播放器实例，用于 PiP 工厂等需要直接访问的场景
    var underlyingPlayer: MediaPlayerProtocol { self.player }
    
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
    
    var audioChannelList: [AudioChannelProtocol] {
        return self.player.audioChannelList
    }
    
    var currentAudioChannel: AudioChannelProtocol?  {
        get {
            return self.player.currentAudioChannel
        }
        
        set {
            self.player.currentAudioChannel = newValue
        }
    }
    
    var playMode = PlayerMode.autoPlayNext
    
    var subtitleYPosition: Float  {
        get {
            return self.player.subtitleYPosition
        }

        set {
            self.player.subtitleYPosition = newValue
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
    
    /// 字幕偏移，单位秒
    var subtitleOffsetTime: Double {
        get {
            return self.player.subtitleOffsetTime
        }
        
        set {
            self.player.subtitleOffsetTime = newValue
        }
    }
    
    var subtitleStyle: Bool {
        get {
            return self.player.subtitleStyle
        }
        
        set {
            self.player.subtitleStyle = newValue
        }
    }
    
    /// 音频偏移，单位秒
    var audioOffsetTime: Double {
        get {
            return self.player.audioOffsetTime
        }
        
        set {
            self.player.audioOffsetTime = newValue
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
    
    /// 字体大小
    var fontSize: Float? {
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
#if os(iOS) || os(tvOS)
        case .mpv:
            self.player = MPVPlayerWrapper()
#endif
        }
        self.setupInit()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.player.stop()
        ANX.logInfo(.player, "[MediaPlayer] 播放器释放")
    }
    
    func setPosition(_ position: Double) {
        self.player.setPosition(position)
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
    
    func terminate() {
        self.player.terminate()
    }
    
    func addMediaToPlayList(_ media: File) {
        if !self.playList.contains(where: { $0 == media }) {
            self.playList.append(media)
            self.delegate?.playerListDidChange(self)
        }
    }
    
    func removeMediaFromPlayList(_ media: File) {
        self.playList.removeAll(where: { $0 == media })
        self.delegate?.playerListDidChange(self)
    }
    
    //MARK: Private Method
    
    #if os(iOS) || os(tvOS)
    @objc private func handleInterreption(_ notice: Notification) {
        guard let interruptionType = notice.userInfo?[AVAudioSessionInterruptionTypeKey] as? AVAudioSession.InterruptionType else { return }

        switch interruptionType {
        case .began:
            if self.isPlaying {
                ANX.logInfo(.player, "[MediaPlayer] 音频被打断，暂停播放")
                self.pause()
            }
        default:
            break
        }
    }
    #endif

    //MARK: Private Method
    private func setupInit() {
#if os(iOS) || os(tvOS)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterreption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
#endif
        
        self.player.stateChangedCallBack = { [weak self] (ins, newState) in
            guard let self = self else { return }
            
            self.delegate?.player(self, stateDidChange: newState)
        }
        
        self.player.endOfFileCallBack = { [weak self] _ in
            guard let self = self else { return }
            
            self.tryPlayNextItem()
        }
        
        self.player.bufferInfoDidChangeCallBack = { [weak self] (ins, file, bufferInfo) in
            guard let self = self else { return }
            
            self.delegate?.player(self, file: file, bufferInfoDidChange: bufferInfo)
        }
        
        self.player.timeChangedCallBack = { [weak self] (ins, time) in
            guard let self = self else { return }
            
            self.delegate?.player(self, currentTime: self.currentTime, totalTime: self.length)
        }
    }
    
    private func changeCurrentItem(_ item: File) -> Bool {
        let shouldChangeMedia = self.delegate?.player(self, shouldChangeMedia: item) == true
        if shouldChangeMedia {
            self.currentPlayItem = item
        }
        return shouldChangeMedia
    }
    
    /// 根据当前播放模式计算下一个播放项（纯计算，无副作用）
    /// - Parameter currentItem: 显式指定当前项，nil 时使用主播放器的 currentPlayItem
    func nextPlayItem(from currentItem: File? = nil) -> File? {
        let current = currentItem ?? self.currentPlayItem

        func nextItemWithCycle(_ cycle: Bool) -> File? {
            if let index = self.playList.firstIndex(where: { $0 == current }) {
                if index == self.playList.count - 1 {
                    return cycle ? self.playList.first : nil
                }
                return self.playList[index + 1]
            }
            return nil
        }

        switch self.playMode {
        case .playOnce:
            return nil
        case .autoPlayNext:
            return nextItemWithCycle(false)
        case .repeatCurrentItem:
            return current
        case .repeatList:
            return nextItemWithCycle(true)
        }
    }

    private func tryPlayNextItem() {
        guard let nextItem = nextPlayItem() else {
            ANX.logInfo(.player, "[MediaPlayer] 播放模式: 无下一集")
            return
        }
        ANX.logInfo(.player, "[MediaPlayer] 自动播放下一集: \(nextItem.fileName)")
        if self.changeCurrentItem(nextItem) {
            self.play(nextItem)
        }
    }
}
