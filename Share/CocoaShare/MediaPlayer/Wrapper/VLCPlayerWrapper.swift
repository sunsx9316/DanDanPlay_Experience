//
//  VLCPlayerWarrper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/10/2.
//

import Foundation
import ANXLog

import VLCKit
#if os(iOS) || os(tvOS)
import UIKit
#else
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
private struct VLCSubtitle: SubtitleProtocol {
    let subtitleName: String
    let index: Int
}

private struct VLCAudioChannel: AudioChannelProtocol {
    let audioName: String
    let audioId: Int64
}

class VLCPlayerWarrper: NSObject, MediaPlayerProtocol {


    private enum Options: String {
        case subtitleYPosition = "--sub-margin"
        case subtitleFontsDir = "--ssa-fontsdir"
        case subtitleFontFamily = "--ssa-fontfamily"
        case subtitleScale = "--sub-text-scale"
        case freetypeFontColor = "--freetype-color"
    }

    private enum InitAction {
        case currentSubtitle
        case volume
        case subtitleOffsetTime
        case speed
        case currentAudioChannel
        case aspectRatio
        case audioOffsetTime
    }


    private var player: VLCMediaPlayer?

    fileprivate var playerTimer: Timer?

    fileprivate var timeIsUpdate = false

    private let endFlagProgress = 0.99

    /// 当前选择的字幕文件
    private var currentSubTitleFile: SubtitleProtocol?

    /// 当前选中的内嵌字幕 track id
    private var currentTextTrackId: String?

    /// 当前选中的音轨 track id
    private var currentAudioTrackId: String?

#if os(iOS)
    private var mediaThumbnailer: MediaThumbnailer?
#endif

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
#if os(iOS)
            if let media = media {
                self.mediaThumbnailer = .init(media: media)
            } else {
                self.mediaThumbnailer = nil
            }
#endif
        }
    }

    var subtitleList: [SubtitleProtocol] {
        guard let textTracks = self.player?.textTracks else { return [] }
        return textTracks.enumerated().compactMap { index, track in
            var name = track.trackName
#if DEBUG
            name = "\(name)(\(index))"
#endif
            return VLCSubtitle(subtitleName: name, index: index)
        }
    }

    var currentSubtitle: SubtitleProtocol? {
        get {
            guard let player = self.player else { return nil }

            if let currentSubTitleFile = self.currentSubTitleFile {
                return currentSubTitleFile
            }

            // 从 textTracks 中找到匹配 trackId 的字幕
            if let trackId = self.currentTextTrackId,
               let index = player.textTracks.firstIndex(where: { $0.trackId == trackId }) {
                var name = player.textTracks[index].trackName
#if DEBUG
                name = "\(name)(\(index))"
#endif
                return VLCSubtitle(subtitleName: name, index: index)
            }
            return nil
        }

        set {
            self.currentSubTitleFile = newValue

            let setup = { [weak self] in
                guard let self = self else { return }

                if let sub = newValue as? VLCSubtitle {
                    ANX.logInfo(.player, "[VLC] 选择字幕: \(sub.subtitleName) (index: \(sub.index))")
                    self.player?.selectTrack(at: Int(sub.index), type: .text)
                    if let tracks = self.player?.textTracks
,
                       sub.index < tracks.count {
                        self.currentTextTrackId = tracks[sub.index].trackId
                    }
                } else if let sub = newValue as? ExternalSubtitle {
                    ANX.logInfo(.player, "[VLC] 添加外部字幕: \(sub.url.lastPathComponent)")
                    self.player?.addPlaybackSlave(sub.url, type: .subtitle, enforce: true)
                } else {
                    ANX.logInfo(.player, "[VLC] 关闭字幕")
                    self.currentTextTrackId = nil
                    self.player?.deselectAllTextTracks()
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
            if let fontSize = fontSize {
                // 映射 app 范围 (10-120) 到 VLC 缩放比例 (0.2-2.0, 默认 1.0)
                let vlcScale = 0.2 + (fontSize - 10) * (2.0 - 0.2) / (120.0 - 10.0)
                ANX.logDebug(.player, "[VLC] 字体大小: \(fontSize) -> VLC scale: \(String(format: "%.2f", vlcScale))")
                // 初始化选项（整数百分比）
                self.mediaOptionsDic[.subtitleScale] = Int(vlcScale * 100)
                // 运行时立即生效，无需重新播放
                self.player?.currentSubTitleFontScale = vlcScale
            } else {
                self.mediaOptionsDic.removeValue(forKey: .subtitleScale)
            }
        }
    }

    var fontName: String? {
        didSet {
            if let fontName = fontName {
                ANX.logDebug(.player, "[VLC] 字体名称: \(fontName)")
                self.mediaOptionsDic[.subtitleFontFamily] = fontName
            } else {
                self.mediaOptionsDic.removeValue(forKey: .subtitleFontFamily)
            }
            self.reloadOptionAndCreatePlayer()
        }
    }

    var fontColor: ANXColor? {
        didSet {
            if let fontColor = fontColor {
                ANX.logDebug(.player, "[VLC] 字体颜色已更改")
                self.mediaOptionsDic[.freetypeFontColor] = fontColor.anxRgbValue
            } else {
                self.mediaOptionsDic.removeValue(forKey: .freetypeFontColor)
            }
            self.reloadOptionAndCreatePlayer()
        }
    }

    var audioChannelList: [AudioChannelProtocol] {
        guard let audioTracks = self.player?.audioTracks else { return [] }
        return audioTracks.enumerated().compactMap { index, track in
            var name = track.trackName
#if DEBUG
            name = "\(name)(\(index))"
#endif
            return VLCAudioChannel(audioName: name, audioId: Int64(index))
        }
    }

    var currentAudioChannel: AudioChannelProtocol? {
        get {
            guard let player = self.player else { return nil }

            if let trackId = self.currentAudioTrackId,
               let index = player.audioTracks.firstIndex(where: { $0.trackId == trackId }) {
                var name = player.audioTracks[index].trackName
#if DEBUG
                name = "\(name)(\(index))"
#endif
                return VLCAudioChannel(audioName: name, audioId: Int64(index))
            }
            return nil
        }

        set {
            let setup = { [weak self] in
                guard let self = self else { return }

                if let audioChannel = newValue {
                    let index = Int(audioChannel.audioId)
                    ANX.logInfo(.player, "[VLC] 选择音轨: \(audioChannel.audioName) (index: \(index))")
                    self.player?.selectTrack(at: Int(index), type: .audio)
                    if let tracks = self.player?.audioTracks
,
                       index < tracks.count {
                        self.currentAudioTrackId = tracks[index].trackId
                    }
                } else {
                    self.currentAudioTrackId = nil
                    self.player?.deselectAllAudioTracks()
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
                return PlayerAspectRatio(rawValue: videoAspectRatio) ?? .default
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

                        #if os(iOS) || os(tvOS)
                        windowScale = window.screen.scale
                        #else
                        windowScale = window.backingScaleFactor
                        #endif

                        let scaleFactor = Float(scale * windowScale)
                        print("scaleFactor:\(scaleFactor)")
                        self.player?.scaleFactor = scaleFactor
                        self.player?.videoAspectRatio = nil
                    }

                case .fourToThree, .sixteenToNine, .sixteenToTen:
                    self.player?.scaleFactor = 0
                    self.player?.videoAspectRatio = newValue.rawValue
                    ANX.logInfo(.player, "[VLC] aspectRatio set: \(newValue.rawValue), player state: \(self.player?.state.rawValue ?? -1)")
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
        ANX.logInfo(.player, "[VLC] 跳转: 进度 \(position)")
        self.player?.position = position

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

    private func setupFontsIfNeeded() {
        guard mediaOptionsDic[.subtitleFontsDir] == nil else { return }

        if let fontDir = playerPrepareFonts() {
            ANX.logInfo(.player, "[VLC] 设置字幕字体目录: \(fontDir)")
            mediaOptionsDic[.subtitleFontsDir] = fontDir
            mediaOptionsDic[.subtitleFontFamily] = playerCustomFontFamilies.first ?? "Source Han Sans SC"
        }
    }

    private func createPlayerInstance() -> VLCMediaPlayer {
        setupFontsIfNeeded()

        let options = self.mediaOptionsDic.compactMap { option -> String? in
            // subtitleYPosition 需要从百分比转换为像素值（考虑视图缩放比例）
            if option.key == .subtitleYPosition, let percentage = option.value as? Float {
                let scaleFactor: CGFloat
                #if os(iOS) || os(tvOS)
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

    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        DispatchQueue.main.async {
            self.stateChangedCallBack?(self, self.state)
            self.checkIsEndPosition(position: self.position)
        }
    }
}
