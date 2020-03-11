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
import dandanplay_native

class PlayerViewController: NSViewController, DDPMediaPlayerDelegate, JHDanmakuEngineDelegate, PlayerListViewControllerDelegate, NSGestureRecognizerDelegate {
    
    private let kShortJumpValue: Int32 = 5
    private let kVolumeAddingValue: CGFloat = 20
    
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
            
            self.mediaPlayer(self.player, statusChange: .nextEpisode)
        }
        
        return view
    }()
    
    private lazy var danmakuRender: JHDanmakuEngine = {
        let danmakuRender = JHDanmakuEngine()
        danmakuRender.delegate = self
        danmakuRender.setUserInfoWithKey(JHScrollDanmakuExtraSpeedKey, value: 1)
        return danmakuRender
    }()
    
    private lazy var player: DDPMediaPlayer = {
        let player = DDPMediaPlayer()
        player.delegate = self
        return player
    }()
    
    private weak var playerListViewController: NSViewController?
    private var playerViewBottomConstraint: ConstraintMakerEditable?
    
    private var playItemMap = [URL : PlayItem]()
    //当前弹幕时间/弹幕数组映射
    private var danmakuDic = [UInt : [JHDanmakuProtocol]]()
    
    private var containerView: NSView = {
        return NSView()
    }()
    
    private var volumeHUD: DDPHUD?
    
    
    init(urls: [URL]) {
        super.init(nibName: nil, bundle: nil)
        
        loadURLs(urls)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func loadView() {
        self.view = NSView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
    }
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.player.mediaView)
        self.containerView.addSubview(self.danmakuRender.canvas)
        self.view.addSubview(self.controlView)
//        self.view.addSubview(self.interfaceView)
        
        self.containerView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalTo(self.view)
        }
        
        self.player.mediaView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.containerView)
        }
        
        self.danmakuRender.canvas.snp.makeConstraints { (make) in
            make.edges.equalTo(self.containerView)
        }
        
        self.controlView.snp.makeConstraints { (make) in
            make.top.equalTo(self.containerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            self.playerViewBottomConstraint = make.bottom.equalToSuperview()
        }
        
        if let first = self.player.playerLists.first,
            let playItem = findPlayItem(first) {
            loadMediaItem(playItem)
        }
        
        self.containerView.addGestureRecognizer(singleClickGestureRecognizer)
        self.containerView.addGestureRecognizer(doubleClickGestureRecognizer)
        
        NotificationCenter.default.addObserver(self, selector: #selector(popoverDidCloseNotification), name: NSPopover.didCloseNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func popoverDidCloseNotification(_ notice: Notification) {
        if let popover = notice.object as? NSPopover,
            popover.contentViewController == self.playerListViewController {
//            self.playerListViewController?.shutDownEngine()
//            self.playerListViewController = nil
        }
    }
    
    
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)
    }
    
    func loadURLs(_ urls: [URL]) {
        let playItems = urls.compactMap { (aURL) -> PlayItem in
            return PlayItem(url: aURL)
        }
        
        for item in playItems {
            if let url = item.url {
                self.playItemMap[url] = item
            }
        }
        
        self.player.addMediaItems(playItems)
    }
    
    func loadDanmaku(_ danmakus: DanmakuCollectionModel?, mediaId: String, title: String? = nil) {
        let playItems = Array(self.playItemMap.values)
        if let item = playItems.first(where: { $0.mediaId == mediaId }) {
            item.collectionModel = danmakus
            loadMediaItem(item)
            
            view.window?.title = title ?? item.url?.lastPathComponent ?? ""
        }
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
    
    //MARK: Private
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
        
        if let danmakus = item.collectionModel?.collection {
            self.danmakuDic = DanmakuManager.shared.conver(danmakus)
            self.player.addMediaItems([item])
            self.player.stop()
            self.player.play(withItem: item)
            self.danmakuRender.currentTime = 0
        } else {
            //请求完弹幕再播放
            if var url = item.url {
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
    
    @objc private func onClickPlayButton() {
        if self.player.isPlaying {
            self.player.pause()
        } else {
            self.player.play()
        }
    }
    
    private func sendDanmaku(_ str: String) {
        
    }
    
    private func showPlayerList() {
        
        if self.playerListViewController == nil {
            let vc = PlayerSettingViewController()
            vc.view.frame = CGRect(x: 0, y: 0, width: max(250, self.view.frame.width * 0.3), height: max(200, self.view.frame.height * 0.5))
//            vc.delegate = self
            self.playerListViewController = vc
            self.present(vc, asPopoverRelativeTo: CGRect(x: 0, y: 0, width: 200, height: 200), of: controlView.playerListButton ?? view, preferredEdge: .minY, behavior: .transient)
        }
    }
    
    private func hidePlayerList() {
        if let vc = self.playerListViewController {
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
    
    //MARK: - NSGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        if gestureRecognizer == singleClickGestureRecognizer && otherGestureRecognizer == doubleClickGestureRecognizer {
            return true
        }
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        if gestureRecognizer == singleClickGestureRecognizer {
            if self.playerListViewController != nil {
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
        case .nextEpisode:
            if let nextItem = player.nextItem, let playItem = self.findPlayItem(nextItem) {
                loadMediaItem(playItem)
            }
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
        
        var collectionModel: DanmakuCollectionModel?
        var mediaId: String {
            return url?.path ?? ""
        }
        
        init(url: URL) {
            super.init()
            self.url = url
        }
    }
}
