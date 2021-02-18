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

class PlayerViewController: NSViewController, MediaPlayerDelegate, JHDanmakuEngineDelegate, PlayerListViewControllerDelegate, NSGestureRecognizerDelegate, NSPopoverDelegate {
    
    private let kShortJumpValue: Int32 = 5
    private let kVolumeAddingValue = 20
    private let controlViewAutoDismissTime: TimeInterval = 2
    
    private func setPlayerProgress(_ progress: CGFloat) {
        _ = self.player.setPosition(progress)
        self.danmakuRender.currentTime = self.player.currentTime
//        self.uiView.updateTime()
    }
   
    private lazy var controlView: DDPPlayerControlView = {
        var view = DDPPlayerControlView.loadFromNib()
        
        view.sliderDidChangeCallBack = { [weak self] (progress) in
            guard let self = self else {
                return
            }
            
            self.setPlayerProgress(progress)
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
            
            self.showPlayerList()
        }
        
        view.onClickPlayNextButtonCallBack = { [weak self] in
            guard let self = self else {
                return
            }
            
            func nextItemWithCycle(_ cycle: Bool) -> File? {
                if let index = self.player.playList.firstIndex(where: { $0.url == self.player.currentPlayItem?.url }) {
                    if index == self.player.playList.count - 1 {
                        return cycle ? self.player.playList.first : nil
                    }
                    return self.player.playList[index + 1]
                }
                return nil
            }

            if let nextItem = nextItemWithCycle(false), let playItem = self.findPlayItem(nextItem) {
                self.addMedia(playItem, play: true)
            }
        }
        
        view.onClickSettingButtonCallBack = { [weak self] in
            guard let self = self else {
                return
            }
            
            self.showPlayerSetting()
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
    
    private lazy var player: MediaPlayer = {
        let player = MediaPlayer()
        player.delegate = self
        player.aspectRatio = .fillToScreen
        return player
    }()
    
    //flutter内存泄漏 先这么写
    private static var playerSettingViewController: PlayerSettingViewController = {
        return PlayerSettingViewController()
    }()
    
    private var playItemMap = [URL : PlayItem]()
    //当前弹幕时间/弹幕数组映射
    private var danmakuDic = [UInt : [JHDanmakuProtocol]]()
    private lazy var danmakuCache: NSCache<NSNumber, DanmakuCollectionModel> = {
        return NSCache<NSNumber, DanmakuCollectionModel>()
    }()
    
    private lazy var containerView = BaseView()
    
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
            
            let items = urls.compactMap({ LocalFile(with: $0) })
            self.loadItem(items)
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
    
    init(items: [File] = []) {
        super.init(nibName: nil, bundle: nil)
        
        self.loadItem(items)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func loadView() {
        self.view = BaseView()
    }
    
    deinit {
        self.autoHiddenTimer?.invalidate()
    }
    
    private func layoutViewsWithAnimate(_ animate: Bool) {
        let controlViewHeight: CGFloat = 70
        let progressHeight: CGFloat = 15
        
        let viewBounds = self.view.bounds
        
        if self.hiddenControlView {
            self.controlView.animator(animate).frame = CGRect(x: 0, y: viewBounds.maxY - progressHeight, width: self.view.bounds.size.width, height: controlViewHeight)
        } else {
            self.controlView.animator(animate).frame = CGRect(x: 0, y: viewBounds.maxY - controlViewHeight, width: self.view.bounds.size.width, height: controlViewHeight)
        }
        
        self.containerView.animator(animate).frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height:self.controlView.frame.minY)
        self.player.mediaView.animator(animate).frame = self.containerView.bounds
        
        var mediaViewFrame = self.containerView.bounds
        mediaViewFrame.origin.y += 10
        mediaViewFrame.size.height -= 10
        if Preferences.shared.subtitleSafeArea {
            mediaViewFrame.size.height *= 0.85
        }
        self.danmakuRender.canvas.animator(animate).frame = mediaViewFrame
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        self.layoutViewsWithAnimate(false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.player.mediaView)
        self.containerView.addSubview(self.danmakuRender.canvas)
        self.containerView.addSubview(self.dragView)
        self.view.addSubview(self.controlView)
        self.view.addTrackingArea(self.trackingArea)
        
        self.dragView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        
        self.containerView.addGestureRecognizer(singleClickGestureRecognizer)
        self.containerView.addGestureRecognizer(doubleClickGestureRecognizer)
        
        Helper.shared.player = self.player
        
        self.player(self.player, mediaDidChange: self.player.playList.first)
        self.changeRepeatMode()
        self.autoShowControlView()
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
                
                self.changeVolume(deltaY)
            }
        } else {
            self.changeVolume(Int(event.scrollingDeltaY))
        }
    }
    
    override func keyDown(with event: NSEvent) {
        let keyCode = Int(event.keyCode)
        
        switch keyCode {
        case kVK_Tab:
            break
        case kVK_Return:
            self.onToggleFullScreen()
        case kVK_Space:
            self.onClickPlayButton()
        case kVK_LeftArrow, kVK_RightArrow:
            let jumpTime = keyCode == kVK_LeftArrow ? TimeInterval(-kShortJumpValue) : TimeInterval(kShortJumpValue)
            let position = self.player.length == 0 ? 0 : (self.player.currentTime + jumpTime) / self.player.length
            self.setPlayerProgress(CGFloat(position))
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
            guard let message = LoadDanmakuMessage.deserialize(from: data) else { return }
            
            let danmakus = message.danmakuCollection
            let mediaId = message.mediaId
            let episodeId = message.episodeId
            
            let playItems = Array(self.playItemMap.values)
            if let item = playItems.first(where: { $0.mediaId == mediaId }) {
                item.playImmediately = message.playImmediately
                item.episodeId = episodeId
                item.matchName = message.title
                
                if let danmakus = danmakus, episodeId > 0 {
                    danmakuCache.setObject(danmakus, forKey: NSNumber(value: episodeId))
                }
                self.addMedia(item, play: true)
            }
        case .syncSetting:
            guard let message = SyncSettingMessage.deserialize(from: data),
                  let enumValue = Preferences.KeyName(rawValue: message.key)else { return }
            
            switch enumValue {
            case .playerSpeed:
                let speed = CGFloat(Preferences.shared.playerSpeed)
                self.player.speed = speed
                self.danmakuRender.systemSpeed = speed
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
        case .loadCustomDanmaku:
            guard let _ = LoadCustomDanmakuMessage.deserialize(from: data) else { return }
            
            let panel = NSOpenPanel()
            panel.allowedFileTypes = ["xml"]
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
                            self.loadCustomDanmaku(url)
                        }
                    }
                }
            }
        default:
            break
        }
    }
    
    func loadItem(_ items: [File]) {
        for item in items {
            let url = item.url
            if self.playItemMap[url] == nil {
                let aItem = PlayItem(media: item)
                self.playItemMap[url] = aItem
                self.player.addMediaToPlayList(item)
            }
        }
    }
    
    
    //MARK: - Private
    
    private func onToggleFullScreen() {
        let window = view.window
        window?.collectionBehavior = .fullScreenPrimary
        window?.toggleFullScreen(nil)
    }
    
    private func changeVolume(_ addBy: Int) {
        self.player.volume += addBy
        var hud = self.volumeHUD
        if hud == nil {
            hud = DDPHUD(style: .normal)
            self.volumeHUD = hud
        }
        
        hud?.title = "音量: \(Int(self.player.volume))"
        hud?.show(at: self.view)
    }
    
    private func addMedia(_ item: PlayItem, play: Bool) {
        self.player.addMediaToPlayList(item.media)
        if play {
            self.player.stop()
            self.player(self.player, mediaDidChange: item.media)
            self.refreshWindowTitle()
        }
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
        self.player.openVideoSubTitle(with: url)
    }
    
    private func loadCustomDanmaku(_ url: URL) {
        DispatchQueue.global().async {
            do {
                let converDic = try DanmakuManager.shared.conver(url)
                DispatchQueue.main.async {
                    self.danmakuDic = converDic
                    self.setPlayerProgress(0)
                }
            } catch let error {
                DispatchQueue.main.async {
                    ProgressHUDHelper.showHUDWithError(error)
                }
            }
        }
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
            ProgressHUDHelper.showHUDWithText("请先匹配视频！")
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
        let vc = PlayerListViewController()
        vc.view.frame = CGRect(x: 0, y: 0, width: max(250, self.view.frame.width * 0.3), height: max(200, self.view.frame.height * 0.5))
        vc.delegate = self
        self.present(vc, asPopoverRelativeTo: CGRect(x: 0, y: 0, width: 200, height: 200), of: controlView.playerListButton ?? view, preferredEdge: .minY, behavior: .transient)
    }
    
    private func showPlayerSetting() {
        let vc = type(of: self).playerSettingViewController
        vc.view.frame = CGRect(x: 0, y: 0, width: max(400, self.view.frame.width * 0.3), height: max(400, self.view.frame.height * 0.5))
        self.present(vc, asPopoverRelativeTo: CGRect(x: 0, y: 0, width: 200, height: 200), of: controlView.playerSettingButtoon ?? view, preferredEdge: .minY, behavior: .transient)
    }
    
    private func findPlayItem(_ protocolItem: File) -> PlayItem? {
        if let protocolItem = protocolItem as? PlayItem {
            return protocolItem
        }
        
        let url = protocolItem.url
        return self.playItemMap[url]
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
            self.autoHiddenTimer = Timer.scheduledTimer(withTimeInterval: controlViewAutoDismissTime, block: { [weak self] (timer) in
                guard let self = self else { return }
                
                self.autoHideMouseControlView()
            }, repeats: false)
            self.autoHiddenTimer?.fireDate = Date(timeIntervalSinceNow: controlViewAutoDismissTime);
            
            completion?()
        }
        
        DispatchQueue.main.async {
            if self.hiddenControlView {
                self.hiddenControlView = false
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    context.duration = 0.2;
                    self.layoutViewsWithAnimate(true)
                }) {
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
                    context.duration = 0.2
                    self.layoutViewsWithAnimate(true)
                })
            }
        }
    }
    
    private func makeFirstResponder(_ responder: NSResponder?) {
        view.window?.makeFirstResponder(responder)
    }
    
    private func changeRepeatMode() {
        switch Preferences.shared.playerMode {
        case .notRepeat:
            player.playMode = .autoPlayNext
        case .repeatAllItem:
            player.playMode = .repeatList
        case .repeatCurrentItem:
            player.playMode = .repeatCurrentItem
        }
    }
    
    private func refreshWindowTitle() {
        if let currentPlayItem = self.player.currentPlayItem,
           let playItem = self.findPlayItem(currentPlayItem) {
            view.window?.title = playItem.title
        } else {
            view.window?.title = self.player.currentPlayItem?.fileName ?? ""
        }
    }
    
    //MARK: - NSGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        if gestureRecognizer == singleClickGestureRecognizer && otherGestureRecognizer == doubleClickGestureRecognizer {
            return true
        }
        return false
    }
    
    
    //MARK: - MediaPlayerDelegate
    func player(_ player: MediaPlayer, stateDidChange state: MediaPlayer.State) {
        switch state {
        case .playing:
            danmakuRender.start()
            controlView.playButton.state = .on
        case .pause, .stop:
            danmakuRender.pause()
            controlView.playButton.state = .off
        }
    }
    
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        self.controlView.updateCurrentTime(currentTime, totalTime: totalTime)
    }
    
    func player(_ player: MediaPlayer, mediaDidChange media: File?) {
        
        guard let media = media,
            let item = findPlayItem(media) else { return }
        
        let danmakuCollection = self.danmakuCache.object(forKey: NSNumber(value: item.episodeId))
        
        func requestDanmaku() {
            if danmakuCollection != nil || item.playImmediately {
                item.playImmediately = false
                let danmakus = danmakuCollection?.collection ?? []
                self.danmakuDic = DanmakuManager.shared.conver(danmakus)
                self.danmakuRender.currentTime = 0
                self.player.play(item.media)
                self.refreshWindowTitle()
            } else {
                //请求完弹幕再播放
                
                self.player.pause()
                
                let message = ParseFileMessage()
                message.mediaId = item.mediaId
                
                let hud = ProgressHUDHelper.showProgressHUD(text: "解析视频中...", progress: 0)

                DispatchQueue.global().async {

                    message.fileName = item.media.fileName
                    message.fileSize = item.media.fileSize
                    
                    //弹弹接口请求需要的大小
                    let parseFileSize = 16777215
                    item.media.getDataWithRange(0...parseFileSize) { (progress) in
                        DispatchQueue.main.async {
                            hud.progress = progress
                        }
                    } completion: { (result) in
                        switch result {
                        case .success(let data):
                            message.fileHash = (data as NSData).md5String()
                            DispatchQueue.main.async {
                                hud.hide(true)
                                MessageHandler.sendMessage(message)
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                hud.hide(true)
                                ProgressHUDHelper.showHUDWithError(error)
                            }
                        }
                    }
                }
            }
        }
        
        if Preferences.shared.autoLoadCusomDanmaku {
            let parentURL = media.url.deletingLastPathComponent()
            let mediaName = media.url.deletingPathExtension().lastPathComponent
            media.fileManager.danmakusOfDirectory(at: parentURL) { (files) in
                if let danmaku = files.first(where: { $0.url.absoluteString.contains(mediaName) }),
                   let danmakus = try? DanmakuManager.shared.conver(danmaku.url) {
                    self.danmakuDic = danmakus
                    self.danmakuRender.currentTime = 0
                    self.player.play(item.media)
                    self.refreshWindowTitle()
                } else {
                    requestDanmaku()
                }
            }
        } else {
            requestDanmaku()
        }
        
    }
    
    //MARK: - PlayerListViewControllerDelegate
    func currentPlayIndexAtPlayerListViewController(_ viewController: PlayerListViewController) -> Int? {
        if let currentPlayItem = player.currentPlayItem {
            return self.player.playList.firstIndex { $0.url == currentPlayItem.url }
        }
        return nil
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, titleAtRow: Int) -> String {
        return self.player.playList[titleAtRow].url.lastPathComponent
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, didSelectedRow: Int) {
        let item = self.player.playList[didSelectedRow]
        if let playItem = findPlayItem(item) {
            self.addMedia(playItem, play: true)
            
            if viewController.presentingViewController != nil {
                viewController.presentingViewController?.dismiss(viewController)
            }
        }
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, didDeleteRowIndexSet: IndexSet) {
        let medias = didDeleteRowIndexSet.compactMap({ self.player.playList[$0] })
        for media in medias.reversed() {
            self.player.removeMediaFromPlayList(media)
        }
    }
    
    func numberOfRowAtPlayerListViewController() -> Int {
        return self.player.playList.count
    }
    
    //MARK: - JHDanmakuEngineDelegate
    func danmakuEngine(_ danmakuEngine: JHDanmakuEngine, didSendDanmakuAtTime time: UInt) -> [JHDanmakuProtocol] {
        return danmakuDic[time] ?? []
    }
    
}


extension PlayerViewController {
    private class PlayItem {
        let media: File
        var playImmediately = false
        var episodeId = 0
        var matchName: String?
        var title: String {
            return self.matchName ?? self.media.fileName
        }
        var mediaId: String {
            return self.media.url.absoluteString
        }
                
        init(media: File) {
            self.media = media
        }
    }
}
