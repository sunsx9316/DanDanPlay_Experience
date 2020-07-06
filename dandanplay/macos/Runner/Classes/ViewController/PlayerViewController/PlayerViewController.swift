//
//  PlayerViewController.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/3.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import SnapKit
import JHDanmakuRender
import FlutterMacOS
import Carbon
import dandanplaystore
import DDPMediaPlayer
import DDPShare
import DDPCategory

class PlayerViewController: NSViewController, DDPMediaPlayerDelegate, JHDanmakuEngineDelegate, PlayerListViewControllerDelegate, NSGestureRecognizerDelegate {
    
    private let kShortJumpValue: Int32 = 5
    private let kVolumeAddingValue: CGFloat = 20
    private let controlViewAutoDismissTime: TimeInterval = 2
    
   
    private lazy var controlView: DDPPlayerControlView = {
        var view = DDPPlayerControlView.loadFromNib()
        
        view.sliderDidChangeCallBack = { [weak self] (progress) in
            guard let self = self else {
                return
            }
            
            self.player.setPosition(progress, completionHandler: nil)
        }
        
        view.playButtonDidClickCallBack = { [weak self] (selected) in
            guard let self = self else {
                return
            }
            self.onClickPlayButton()
        }
        
        view.danmakuButtonDidClickCallBack = { [weak self] (selected) in
            guard let self = self else {
                return
            }
            
            self.danmakuRender.canvas.isHidden = selected
        }
        
        view.sendDanmakuCallBack = { [weak self] (str) in
            guard let self = self else {
                return
            }
            
            self.sendDanmaku(str)
        }
        
        view.onClickPlayListButtonCallBack = { [weak self] in
            guard let self = self else {
                return
            }
            
            if (self.playerListViewController != nil) {
                self.hidePlayerList()
            } else {
                self.showPlayerList()
            }
        }
        
        view.onClickPlayNextButtonCallBack = { [weak self] in
            guard let self = self else {
                return
            }
            
            if let nextItem = self.player.nextItem, let playItem = self.findPlayItem(nextItem) {
                self.loadMediaItem(playItem)
            }
        }
        
        view.onClickSettingButtonCallBack = { [weak self] in
            guard let self = self else {
                return
            }
            
            if (self.playerSettingViewController != nil) {
                self.hidePlayerSetting()
            } else {
                self.showPlayerSetting()
            }
        }
        
        return view
    }()
    
    private lazy var danmakuRender: JHDanmakuEngine = {
        let danmakuRender = JHDanmakuEngine()
        danmakuRender.delegate = self
        danmakuRender.setUserInfoWithKey(JHScrollDanmakuExtraSpeedKey, value: 1)
        
        danmakuRender.globalFont = NSFont.systemFont(ofSize: CGFloat(Preferences.shared.danmakuFontSize))
        danmakuRender.systemSpeed = CGFloat(Preferences.shared.danmakuSpeed)
        danmakuRender.canvas.alphaValue = CGFloat(Preferences.shared.danmakuAlpha)
        return danmakuRender
    }()
    
    private lazy var player: DDPMediaPlayer = {
        let player = DDPMediaPlayer()
        player.delegate = self
        return player
    }()
    
    private weak var playerListViewController: NSViewController?
    private weak var playerSettingViewController: NSViewController?
    
    private var playItemMap = [URL : PlayItem]()
    //当前弹幕时间/弹幕数组映射
    private var danmakuDic = [UInt : [JHDanmakuProtocol]]()
    private lazy var danmakuCache: NSCache<NSNumber, DanmakuCollectionModel> = {
        return NSCache<NSNumber, DanmakuCollectionModel>()
    }()
    
    private var containerView: NSView = {
        return NSView()
    }()
    
    private var volumeHUD: DDPHUD?
    
    private lazy var singleClickGestureRecognizer: NSClickGestureRecognizer = {
        let clickGes = NSClickGestureRecognizer(target: self, action: #selector( mouseClickGesture(_:)))
        clickGes.delegate = self
        return clickGes
    }()
    
    private lazy var doubleClickGestureRecognizer: NSClickGestureRecognizer = {
        let doubleClickGes = NSClickGestureRecognizer(target: self, action: #selector(doubleClickGesture(_:)))
        doubleClickGes.numberOfClicksRequired = 2
        return doubleClickGes
    }()
    
    private lazy var dragView: DragView = {
        let view = DragView()
        view.dragFilesCallBack = { [weak self] (urls) in
            guard let self = self else {
                return
            }
            
            self.loadURLs(urls)
        }
        return view
    }()
    
    private lazy var trackingArea: NSTrackingArea = {
        var trackingArea = NSTrackingArea(rect: self.view.bounds, options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)
        return trackingArea
    }()
    
    private var autoHiddenTimer: Timer?
    private var hiddenControlView = false
    
    //MARK: - life cycle
    
    init(urls: [URL]) {
        super.init(nibName: nil, bundle: nil)
        
        loadURLs(urls)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.player.mediaView)
        self.containerView.addSubview(self.danmakuRender.canvas)
        self.containerView.addSubview(self.dragView)
        self.view.addSubview(self.controlView)
        self.view.addTrackingArea(self.trackingArea)
        
        self.containerView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalTo(self.view)
        }
        
        self.player.mediaView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.containerView)
        }
        
        self.danmakuRender.canvas.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalTo(self.containerView)
            if Preferences.shared.subtitleSafeArea {
                make.height.equalTo(self.containerView).multipliedBy(0.85)
            } else {
                make.height.equalTo(self.containerView)
            }
        }
        
        self.controlView.snp.makeConstraints { (make) in
            make.top.equalTo(self.containerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        self.dragView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        if let first = self.player.playerLists.first,
            let playItem = findPlayItem(first) {
            loadMediaItem(playItem)
        }
        
        self.containerView.addGestureRecognizer(singleClickGestureRecognizer)
        self.containerView.addGestureRecognizer(doubleClickGestureRecognizer)
        
        Helper.shared.player = self.player
        
        changeRepeatMode()
        autoShowControlView()
    }
    
    
    override func viewDidAppear() {
        super.viewDidAppear()
        makeFirstResponder(view)
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.hasPreciseScrollingDeltas {
            if event.momentumPhase == [] {
                var deltaY = Int(event.deltaY)
                var absDeltaY = labs(deltaY)
                if absDeltaY != 0 {
                    let remainder = absDeltaY % 2
                    if remainder == 1 {
                        absDeltaY = absDeltaY - remainder
                    }
                }
                
                deltaY = deltaY > 0 ? -absDeltaY : absDeltaY
                if event.isDirectionInvertedFromDevice == false {
                    deltaY *= -1;
                }
                
                self.changeVolume(CGFloat(deltaY))
            }
        } else {
            self.changeVolume(event.scrollingDeltaY)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        let keyCode = Int(event.keyCode)
        
        switch keyCode {
        case kVK_Tab:
            break
//            makeFirstResponder(self.controlView.inputTextField)
//            self.autoShowControlView {
//                self.autoHiddenTimer?.invalidate()
//            }
        case kVK_Return:
            self.onToggleFullScreen()
        case kVK_Space:
            self.onClickPlayButton()
        case kVK_LeftArrow, kVK_RightArrow:
            let jumpTime = keyCode == kVK_LeftArrow ? -kShortJumpValue : kShortJumpValue
            self.player.jump(jumpTime) { [weak self] (time) in
                guard let self = self else {
                    return
                }
                
                self.danmakuRender.currentTime = time
            }
        case kVK_UpArrow, kVK_DownArrow:
            let volumeValue = keyCode == kVK_DownArrow ? -kVolumeAddingValue : kVolumeAddingValue
            changeVolume(volumeValue)
        default:
            super.keyDown(with: event)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        autoShowControlView { [weak self] in
            guard let self = self else {
                return
            }
            
            let position = event.locationInWindow
            if (self.controlView.frame.contains(position)) {
                self.autoHiddenTimer?.invalidate()
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        mouseMoved(with: event)
    }
    
    //MARK: - Public
    func parseMessage(_ type: MessageType, data: [String : Any]?) {
        
        switch type {
        case .loadDanmaku:
            if let message = LoadDanmakuMessage.deserialize(from: data) {
                
                let danmakus = message.danmakuCollection
                let mediaId = message.mediaId
                let episodeId = message.episodeId
                
                let playItems = Array(self.playItemMap.values)
                if let item = playItems.first(where: { $0.mediaId == mediaId }) {
                    item.playImmediately = message.playImmediately
                    item.episodeId = episodeId
                    
                    if let danmakus = danmakus, episodeId > 0 {
                        danmakuCache.setObject(danmakus, forKey: NSNumber(value: episodeId))
                    }
                    loadMediaItem(item)
                    
                    view.window?.title = message.title ?? item.url?.lastPathComponent ?? ""
                }
            }
        case .syncSetting:
            if let message = SyncSettingMessage.deserialize(from: data) {
                
                guard let enumValue = Preferences.KeyName(rawValue: message.key) else { return }
                
                switch enumValue {
                case .playerSpeed:
                    self.player.speed = Float(Preferences.shared.playerSpeed)
                case .danmakuAlpha:
                    danmakuRender.canvas.alphaValue = CGFloat(Preferences.shared.danmakuAlpha)
                case .danmakuCount:
                    let danmakuCount = Preferences.shared.danmakuCount
                    danmakuRender.limitCount = UInt(danmakuCount == Preferences.shared.danmakuUnlimitCount ? 0 : danmakuCount)
                case .danmakuFontSize:
                    let danmakuFontSize = CGFloat(Preferences.shared.danmakuFontSize)
                    danmakuRender.globalFont = NSFont.systemFont(ofSize: danmakuFontSize)
                case .danmakuSpeed:
                    danmakuRender.systemSpeed = CGFloat(Preferences.shared.danmakuSpeed)
                case .subtitleSafeArea:
                    self.danmakuRender.canvas.snp.remakeConstraints { (make) in
                        make.top.leading.trailing.equalTo(self.containerView)
                        if Preferences.shared.subtitleSafeArea {
                            make.height.equalTo(self.containerView).multipliedBy(0.85)
                        } else {
                            make.height.equalTo(self.containerView)
                        }
                    }
                case .playerMode:
                    changeRepeatMode()
                default:
                    break
                }
                
            }
            break
        default:
            break
        }
    }
    
    func loadURLs(_ urls: [URL]) {
        
        var arr = [PlayItem]()
        for url in urls {
            if self.playItemMap[url] == nil {
                let item = PlayItem(url: url)
                arr.append(item)
                self.playItemMap[url] = item
            }
        }
        
        self.player.addMediaItems(arr)
        if !urls.isEmpty && self.isViewLoaded {
            if let item = self.playItemMap[urls[0]] {
                loadMediaItem(item)
            }
        }
    }
    
    //MARK: - Private
    
    private func onToggleFullScreen() {
        let window = view.window
        window?.collectionBehavior = .fullScreenPrimary
        window?.toggleFullScreen(nil)
    }
    
    private func changeVolume(_ addBy: CGFloat) {
        self.player.volumeJump(addBy)
        var hud = self.volumeHUD
        if hud == nil {
            hud = DDPHUD(style: .normal)
            self.volumeHUD = hud
        }
        
        hud?.title = "音量: \(Int(self.player.volume))"
        hud?.show(at: self.view)
    }
    
    private func loadMediaItem(_ item: PlayItem) {
        
        if let vc = self.playerListViewController {
            self.dismiss(vc)
            self.playerListViewController = nil
        }
        
        self.player.addMediaItems([item])
        self.player.stop()
        self.player.play(withItem: item)
    }
    
    @IBAction func onClickOpenSubtitleMenuItem(_ sender: NSMenuItem) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = Helper.shared.subTitlePathExtension
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        weak var weakPanel = panel
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { [weak self] (result) in
                guard let self = self else {
                    return
                }
                
                if result == .OK {
                    if let url = weakPanel?.urls.first {
                        self.loadSubtitle(url)
                    }
                }
            }
        }
    }
    
    private func loadSubtitle(_ url: URL) {
        player.openVideoSubTitles(fromFile: url)
    }
    
    @IBAction func onClickSubtitleOffsetAdd(_ sender: NSMenuItem) {
        player.subtitleDelay += 0.5
    }
    
    @IBAction func onClickSubtitleOffsetSub(_ sender: NSMenuItem) {
        player.subtitleDelay -= 0.5
    }
    
    @IBAction func onClickSubtitleOffsetReset(_ sender: NSMenuItem) {
        player.subtitleDelay = 0
    }
    
    
    @objc private func onClickPlayButton() {
        if self.player.isPlaying {
            self.player.pause()
        } else {
            self.player.play()
        }
    }
    
    private func sendDanmaku(_ str: String) {
        
        guard let currentPlayItem = self.player.currentPlayItem,
            let playItem = findPlayItem(currentPlayItem),
            !str.isEmpty else { return }
        
        if playItem.episodeId == 0 {
            ProgressHUDHelper.showHUD(text: "请先匹配视频！")
            return
        }
        
        let danmaku = DanmakuModel()
        danmaku.color = self.controlView.sendanmakuColor
        danmaku.mode = DanmakuModel.Mode(rawValue: Int(self.controlView.sendanmakuStyle.rawValue)) ?? .normal
        danmaku.message = str
        danmaku.time = self.player.currentTime
        
        let msg = SendDanmakuMessage()
        msg.danmaku = danmaku
        msg.episodeId = playItem.episodeId
        MessageHandler.sendMessage(msg)
        self.danmakuRender.sendDanmaku(DanmakuManager.shared.conver(danmaku))
    }
    
    private func showPlayerList() {
        if self.playerListViewController == nil {
            let vc = PlayerListViewController()
            vc.view.frame = CGRect(x: 0, y: 0, width: max(250, self.view.frame.width * 0.3), height: max(200, self.view.frame.height * 0.5))
            vc.delegate = self
            self.playerListViewController = vc
            self.present(vc, asPopoverRelativeTo: CGRect(x: 0, y: 0, width: 200, height: 200), of: controlView.playerListButton ?? view, preferredEdge: .minY, behavior: .transient)
        }
    }
    
    private func hidePlayerList() {
        if let vc = self.playerListViewController {
            self.dismiss(vc)
        }
    }
    
    private func showPlayerSetting() {
        if self.playerSettingViewController == nil {
            let vc = PlayerSettingViewController()
            
            vc.view.frame = CGRect(x: 0, y: 0, width: max(400, self.view.frame.width * 0.3), height: max(400, self.view.frame.height * 0.5))
            self.playerSettingViewController = vc
            self.present(vc, asPopoverRelativeTo: CGRect(x: 0, y: 0, width: 200, height: 200), of: controlView.playerSettingButtoon ?? view, preferredEdge: .minY, behavior: .transient)
        }
    }
    
    private func hidePlayerSetting() {
        if let vc = self.playerSettingViewController {
            self.dismiss(vc)
        }
    }
    
    private func findPlayItem(_ protocolItem: DDPMediaItemProtocol) -> PlayItem? {
        if let protocolItem = protocolItem as? PlayItem {
            return protocolItem
        }
        
        if let url = protocolItem.url {
            return self.playItemMap[url]
        }
        
        return nil
    }
    
    @objc private func mouseClickGesture(_ sender: NSClickGestureRecognizer) {
        onClickPlayButton()
    }
    
    @objc private func doubleClickGesture(_ sender: NSClickGestureRecognizer) {
        onToggleFullScreen()
    }
    
    private func autoShowControlView(completion: (() -> ())? = nil) {
        func startHiddenTimerAction() {
            self.autoHiddenTimer?.invalidate()
            self.autoHiddenTimer = Timer.scheduledTimer(withTimeInterval: controlViewAutoDismissTime, block: { (timer) in
                self.autoHideMouseControlView()
            }, repeats: false)
            self.autoHiddenTimer?.fireDate = Date(timeIntervalSinceNow: controlViewAutoDismissTime);
            
            completion?()
        }
        
        DispatchQueue.main.async {
            if self.hiddenControlView {
                self.hiddenControlView = false
                
                var frame = self.controlView.frame
                frame.origin.y = 0
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    context.duration = 0.2;
                    self.controlView.animator().frame = frame
                }) {
                    self.controlView.snp.remakeConstraints { (make) in
                        make.top.equalTo(self.containerView.snp.bottom)
                        make.leading.trailing.equalToSuperview()
                        make.bottom.equalToSuperview()
                    }
                    
                    startHiddenTimerAction()
                }
            } else {
                startHiddenTimerAction();
            }
        }
    }
    
    private func autoHideMouseControlView() {
        DispatchQueue.main.async {
            //显示状态 隐藏
            if self.hiddenControlView == false {
                self.hiddenControlView = true
                self.autoHiddenTimer?.invalidate()
                NSCursor.setHiddenUntilMouseMoves(true)
                var frame = self.controlView.frame
                let height = self.controlView.frame.height > 0 ? self.controlView.frame.height : 70
                let progressHeight: CGFloat = 15
                frame.origin.y = -(height - progressHeight)
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    context.duration = 0.2;
                    self.controlView.animator().frame = frame
                }) {
                    self.controlView.snp.remakeConstraints { (make) in
                        make.top.equalTo(self.containerView.snp.bottom)
                        make.leading.trailing.equalToSuperview()
                        make.bottom.equalToSuperview().offset(height - progressHeight)
                    }
                }
            }
        }
    }
    
    private func makeFirstResponder(_ responder: NSResponder?) {
        view.window?.makeFirstResponder(responder)
    }
    
    private func changeRepeatMode() {
        if let mode = DDPMediaPlayerRepeatMode(rawValue: UInt(Preferences.shared.playerMode.rawValue)) {
            player.repeatMode = mode
        }
    }
    
    //MARK: - NSGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        if gestureRecognizer == singleClickGestureRecognizer && otherGestureRecognizer == doubleClickGestureRecognizer {
            return true
        }
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        if gestureRecognizer == singleClickGestureRecognizer {
            if self.playerListViewController != nil ||
                self.playerSettingViewController != nil {
                return false
            }
        }
        return true
    }
    
    
    //MARK: - DDPMediaPlayerDelegate
    func mediaPlayer(_ player: DDPMediaPlayer, statusChange status: DDPMediaPlayerStatus) {
        switch status {
        case .playing:
            danmakuRender.start()
            controlView.playButton.state = .on
        case .pause, .stop:
            danmakuRender.pause()
            controlView.playButton.state = .off
        case .unknow:
            break
        @unknown default:
            break
        }
    }
    
    func mediaPlayer(_ player: DDPMediaPlayer, rateChange rate: Float) {
        danmakuRender.systemSpeed = CGFloat(rate)
    }
    
    func mediaPlayer(_ player: DDPMediaPlayer, userJumpWithTime time: TimeInterval) {
        danmakuRender.currentTime = time
        if !player.isPlaying {
            danmakuRender.pause()
        }
    }
    
    func mediaPlayer(_ player: DDPMediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        controlView.updateCurrentTime(currentTime, totalTime: totalTime)
    }
    
    func mediaPlayer(_ player: DDPMediaPlayer, mediaDidChange media: DDPMediaItemProtocol?) {
        guard let media = media,
            let item = findPlayItem(media) else { return }
        
        let danmakus = self.danmakuCache.object(forKey: NSNumber(value: item.episodeId))?.collection ?? []
        
        if item.playImmediately || !danmakus.isEmpty {
            self.danmakuDic = DanmakuManager.shared.conver(danmakus)
            self.danmakuRender.currentTime = 0
            self.player.play()
        } else {
            //请求完弹幕再播放
            if var url = item.url {
                self.player.pause()
                
                let message = ParseFileMessage()
                message.mediaId = item.mediaId
                
                let attributesOfItem = try? FileManager.default.attributesOfItem(atPath:
                    url.path)
                let size = attributesOfItem?[.size] as? Int ?? 0
                message.fileSize = size
                
                if let data = try? FileHandle(forReadingFrom: url).readData(ofLength: min(16777216, size)) as NSData {
                    message.fileHash = data.md5String()
                }
                
                url.deletePathExtension()
                message.fileName = url.lastPathComponent
                MessageHandler.sendMessage(message)
            }
        }
        
    }
    
    //MARK: - PlayerListViewControllerDelegate
    func currentPlayIndexAtPlayerListViewController(_ viewController: PlayerListViewController) -> Int? {
        if let currentPlayItem = player.currentPlayItem {
            return player.index(withItem: currentPlayItem)
        }
        return nil
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, titleAtRow: Int) -> String {
        return self.player.playerLists[titleAtRow].url?.lastPathComponent ?? ""
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, didSelectedRow: Int) {
        let item = self.player.playerLists[didSelectedRow]
        if let playItem = findPlayItem(item) {
            loadMediaItem(playItem)
        }
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, didDeleteRowIndexSet: IndexSet) {
        player.removeMedia(with: didDeleteRowIndexSet)
    }
    
    func numberOfRowAtPlayerListViewController() -> Int {
        return self.player.playerLists.count
    }
    
    //MARK: - JHDanmakuEngineDelegate
    func danmakuEngine(_ danmakuEngine: JHDanmakuEngine, didSendDanmakuAtTime time: UInt) -> [JHDanmakuProtocol] {
        return danmakuDic[time] ?? []
    }
    
}


extension PlayerViewController {
    private class PlayItem: NSObject, DDPMediaItemProtocol {

        var url: URL?
        var mediaOptions: [AnyHashable : Any]?
        var playImmediately = false
        
        var mediaId: String {
            return url?.path ?? ""
        }
        var episodeId = 0
        
        init(url: URL) {
            super.init()
            self.url = url
        }
    }
}
