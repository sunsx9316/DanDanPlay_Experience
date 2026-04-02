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
import UIKit
#else
import VLCKit
import AppKit
#endif

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

/// 内嵌字幕
private struct Subtitle: SubtitleProtocol {
    let subtitleName: String
    let index: Int
}

private struct AudioChannel: AudioChannelProtocol {
    let audioName: String
    let audioId: Int64
}

class VLCPlayerWarrper: NSObject, MediaPlayerProtocol {
    
    
    private enum Options: String {
        case subtitleYPosition = "--sub-margin"
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
    
    /// 当前选择的字幕文件
    private var currentSubTitleFile: SubtitleProtocol?
    
    private var mediaThumbnailer: MediaThumbnailer?
    
    lazy var mediaView: ANXView = {
        let view = ANXView()
        view.backgroundColor = .black
        return view
    }();
    
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
            let media = self.currentPlayItem?.createVLCMedia(delegate: self)
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
            
            let setup = { [weak self] in
                guard let self = self else { return }

                if let sub = newValue as? Subtitle {
                    ANX.logInfo(.player, "[VLC] 选择字幕: \(sub.subtitleName) (index: \(sub.index))")
                    self.player?.currentVideoSubTitleIndex = Int32(sub.index)
                } else if let sub = newValue as? ExternalSubtitle {
                    ANX.logInfo(.player, "[VLC] 添加外部字幕: \(sub.url.lastPathComponent)")
                    self.player?.addPlaybackSlave(sub.url, type: .subtitle, enforce: true)
                } else {
                    ANX.logInfo(.player, "[VLC] 关闭字幕")
                }
            }
            
            if self.player != nil {
                setup()
            }
            
            self.initActionDic[.currentSubtitle] = setup
        }
    }
    
    var subtitleYPosition: Float {
        get {
            return self.mediaOptionsDic[.subtitleYPosition] as? Float ?? 0
        }

        set {
            if newValue != (self.mediaOptionsDic[.subtitleYPosition] as? Float ?? 0) {
                ANX.logDebug(.player, "[VLC] 字幕位置: \(newValue)%")
                self.mediaOptionsDic[.subtitleYPosition] = newValue
                self.reloadOptionAndCreatePlayer()
            }
        }
    }
    
    var volume: Int {
        get {
            return Int(self.player?.audio?.volume ?? 0)
        }

        set {
            let setup = {  [weak self] in
                guard let self = self else { return }
                ANX.logDebug(.player, "[VLC] 音量: \(newValue)")
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
            let setup = { [weak self] in
                guard let self = self else { return }
                ANX.logDebug(.player, "[VLC] 字幕延迟: \(newValue)s")
                self.player?.currentVideoSubTitleDelay = Int(newValue * -1000000.0)
            }

            if self.player != nil {
                setup()
            }

            self.initActionDic[.subtitleOffsetTime] = setup
        }
    }

    var subtitleStyle: Bool  {
        set {}
        get {
            return true
        }
    }

    var audioOffsetTime: Double {
        get {
            return Double(self.player?.currentAudioPlaybackDelay ?? 0) / -1000000.0
        }

        set {
            let setup = { [weak self] in
                guard let self = self else { return }
                ANX.logDebug(.player, "[VLC] 音频延迟: \(newValue)s")
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
            let setup = { [weak self] in
                guard let self = self else { return }
                ANX.logInfo(.player, "[VLC] 播放速度: \(newValue)")
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
            let setup = { [weak self] in
                guard let self = self else { return }

                if let fontSize = self.fontSize {
                    ANX.logDebug(.player, "[VLC] 字体大小: \(fontSize)")
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

            let setup = { [weak self] in
                guard let self = self else { return }

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
                ANX.logDebug(.player, "[VLC] 字体颜色已更改")
                self.player?.anx_setTextRendererFontColor(fontColor.rgbValue() as NSNumber)
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
            let setup = { [weak self] in
                guard let self = self else { return }

                if let audioChannel = newValue {
                    ANX.logInfo(.player, "[VLC] 选择音轨: \(audioChannel.audioName) (id: \(audioChannel.audioId))")
                    self.player?.currentAudioTrackIndex = Int32(audioChannel.audioId)
                } else {
                    self.player?.currentAudioTrackIndex = -1
                }
                return
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
    
    var endOfFileCallBack: ((MediaPlayerProtocol) -> Void)?
    
    var aspectRatio: PlayerAspectRatio {
        get {
            if let videoAspectRatio = self.player?.videoAspectRatio {
                let str = String(cString: videoAspectRatio)
                return PlayerAspectRatio(rawValue: str) ?? .default
            }
            return .default
        }
        
        set {
            let setup = { [weak self] in
                guard let self = self else { return }
                
                switch newValue {
                case .default:
                    self.player?.scaleFactor = 0
                    self.player?.videoAspectRatio = nil
                    self.player?.videoCropGeometry = nil
                case .fillToScreen:
                    if let window = self.mediaView.window {
                        
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
                        windowScale = window.screen.scale
                        #else
                        windowScale = window.backingScaleFactor
                        #endif
                        
                        let scaleFactor = Float(scale * windowScale)
                        print("scaleFactor:\(scaleFactor)")
                        self.player?.scaleFactor = scaleFactor
                        self.player?.videoCropGeometry = nil
                        self.player?.videoAspectRatio = nil
                    }
                
                case .fourToThree, .sixteenToNine, .sixteenToTen:
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
        ANX.logInfo(.player, "[VLC] 跳转: 进度 \(position)")
        self.player?.position = Float(position)

        checkIsEndPosition(position: position)
    }
    
    func play(_ media: File) {
        ANX.logInfo(.player, "[VLC] 播放文件: \(media.fileName)")
        self.currentPlayItem = media
        self.player?.play()
    }

    func play() {
        ANX.logInfo(.player, "[VLC] 播放")
        self.player?.play()
    }

    func pause() {
        ANX.logInfo(.player, "[VLC] 暂停")
        self.player?.pause()
    }

    func stop() {
        ANX.logInfo(.player, "[VLC] 停止")
        self.player?.stop()
    }

    func terminate() {
        ANX.logInfo(.player, "[VLC] 终止")
        stop()
    }
    
    deinit {
        self.playerTimer?.invalidate()
    }
    
    //MARK: Private Method
    private func subtitleWithIndexInPlayer(_ index: Int) -> Subtitle? {
        guard let player = self.player else { return nil }
        
        if index < player.videoSubTitlesIndexes.count,
           let indexNumber = player.videoSubTitlesIndexes[index] as? Int {
            
            var name: String
            if index < player.videoSubTitlesNames.count {
                name = player.videoSubTitlesNames[index] as? String ?? "未知名称"
                #if DEBUG
                name = "\(name)(\(index))"
                #endif
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
           let indexNumber = player.audioTrackIndexes[index] as? Int64 {
            
            var name: String
            if index < player.audioTrackNames.count {
                name = player.audioTrackNames[index] as? String ?? "未知名称"
                #if DEBUG
                name = "\(name)(\(index))"
                #endif
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
        let options = self.mediaOptionsDic.compactMap { option -> String? in
            // subtitleYPosition 需要从百分比转换为像素值（考虑视图缩放比例）
            if option.key == .subtitleYPosition, let percentage = option.value as? Float {
                let scaleFactor: CGFloat
                #if os(iOS)
                scaleFactor = self.mediaView.window?.screen.scale ?? UIScreen.main.scale
                #else
                scaleFactor = self.mediaView.window?.backingScaleFactor ?? 1.0
                #endif
                let pixelValue = Int(self.mediaView.bounds.height * scaleFactor * CGFloat(percentage) / 100)
                return "\(option.key.rawValue)=\(pixelValue)"
            }
            return "\(option.key.rawValue)=\(option.value)"
        }

        let player = VLCMediaPlayer(options: options)
        player.drawable = self.mediaView
        player.delegate = self

        return player
    }
    
    private func checkIsEndPosition(position: Double) {
        if position >= self.endFlagProgress {
            self.endOfFileCallBack?(self)
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
                self.checkIsEndPosition(position: self.position)
            }
            
            if self.timeIsUpdate == false {
                self.timeIsUpdate = true
                self.stateChangedCallBack?(self, self.state)
                self.checkIsEndPosition(position: self.position)
            }
            
            self.timeChangedCallBack?(self, self.position)
        }
        
    }
    
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        self.stateChangedCallBack?(self, self.state)
        self.checkIsEndPosition(position: self.position)
    }
}
