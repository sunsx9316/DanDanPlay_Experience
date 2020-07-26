//
//  PlayerViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/26.
//

import UIKit
import DDPShare
import DDPMediaPlayer
import JHDanmakuRender
import dandanplaystore
import SnapKit
import YYCategories
import dandanplayfilepicker

private var FileBrowerManagerTransitioningKey = 0

class PlayerViewController: UIViewController {
    
    private let kShortJumpValue: Int32 = 5
    private let kVolumeAddingValue: CGFloat = 20
    
    private lazy var uiView: PlayerUIView = {
        let view = PlayerUIView.fromNib()
        view.delegate = self
        return view
    }()
    
    private lazy var danmakuRender: JHDanmakuEngine = {
        let danmakuRender = JHDanmakuEngine()
        danmakuRender.delegate = self
        danmakuRender.setUserInfoWithKey(JHScrollDanmakuExtraSpeedKey, value: 1)
        
        danmakuRender.globalFont = UIFont.systemFont(ofSize: CGFloat(Preferences.shared.danmakuFontSize))
        danmakuRender.systemSpeed = CGFloat(Preferences.shared.danmakuSpeed)
        danmakuRender.canvas.alpha = CGFloat(Preferences.shared.danmakuAlpha)
        return danmakuRender
    }()
    
    private lazy var player: DDPMediaPlayer = {
        let player = DDPMediaPlayer()
        player.delegate = self
        return player
    }()
    
    private var playItemMap = [URL : PlayItem]()
    //当前弹幕时间/弹幕数组映射
    private var danmakuDic = [UInt : [JHDanmakuProtocol]]()
    private lazy var danmakuCache: NSCache<NSNumber, DanmakuCollectionModel> = {
        return NSCache<NSNumber, DanmakuCollectionModel>()
    }()
    
    private var containerView: UIView = {
        return UIView()
    }()
    
    private var autoHiddenTimer: Timer?
    private var hiddenControlView = false
    private var fileBrower: FileBrowerManager?
    
    //MARK: - life cycle
    
    init(urls: [URL]) {
        super.init(nibName: nil, bundle: nil)
        
        loadURLs(urls)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIViewController.attemptRotationToDeviceOrientation()
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        if self.player.isPlaying == false {
//            self.player.play()
//        }
//    }

//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//
//        if self.player.isPlaying {
//            self.player.pause()
//        }
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.player.mediaView)
        self.containerView.addSubview(self.danmakuRender.canvas)
        self.view.addSubview(self.uiView)
        
        self.containerView.snp.makeConstraints { (make) in
            make.top.leading.trailing.bottom.equalTo(self.view)
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
        
        self.uiView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        
        changeRepeatMode()
        autoShowControlView()
        if let first = self.player.playerLists.first,
            let playItem = findPlayItem(first) {
            loadMediaItem(playItem)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        if self.isViewLoaded == false {
            return false
        }
        return true
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeLeft
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        if !isViewLoaded {
            return false
        }
        
        return true
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
                    uiView.titleLabel.text = message.title ?? item.url?.lastPathComponent ?? ""
                }
            }
        case .syncSetting:
            if let message = SyncSettingMessage.deserialize(from: data) {
                
                guard let enumValue = Preferences.KeyName(rawValue: message.key) else { return }
                
                switch enumValue {
                case .playerSpeed:
                    self.player.speed = Float(Preferences.shared.playerSpeed)
                case .danmakuAlpha:
                    danmakuRender.canvas.alpha = CGFloat(Preferences.shared.danmakuAlpha)
                case .danmakuCount:
                    let danmakuCount = Preferences.shared.danmakuCount
                    danmakuRender.limitCount = UInt(danmakuCount == Preferences.shared.danmakuUnlimitCount ? 0 : danmakuCount)
                case .danmakuFontSize:
                    let danmakuFontSize = CGFloat(Preferences.shared.danmakuFontSize)
                    danmakuRender.globalFont = UIFont.systemFont(ofSize: danmakuFontSize)
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
//        if !urls.isEmpty && self.isViewLoaded {
//            if let item = self.playItemMap[urls[0]] {
//                loadMediaItem(item)
//            }
//        }
    }
    
    //MARK: - Private
    
    private func changeVolume(_ addBy: CGFloat) {
        self.player.volumeJump(addBy)
//        var hud = self.volumeHUD
//        if hud == nil {
//            hud = DDPHUD(style: .normal)
//            self.volumeHUD = hud
//        }
//
//        hud?.title = "音量: \(Int(self.player.volume))"
//        hud?.show(at: self.view)
    }
    
    private func loadMediaItem(_ item: PlayItem) {
        
//        if let vc = self.playerListViewController {
//            self.dismiss(vc)
//            self.playerListViewController = nil
//        }
        
        self.player.addMediaItems([item])
        self.player.stop()
        self.player.play(withItem: item)
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
//            ProgressHUDHelper.showHUD(text: "请先匹配视频！")
            return
        }
        
//        let danmaku = DanmakuModel()
//        danmaku.color = self.controlView.sendanmakuColor
//        danmaku.mode = DanmakuModel.Mode(rawValue: Int(self.controlView.sendanmakuStyle.rawValue)) ?? .normal
//        danmaku.message = str
//        danmaku.time = self.player.currentTime
//
//        let msg = SendDanmakuMessage()
//        msg.danmaku = danmaku
//        msg.episodeId = playItem.episodeId
//        MessageHandler.sendMessage(msg)
//        self.danmakuRender.sendDanmaku(DanmakuManager.shared.conver(danmaku))
    }
    
    private func showPlayerList() {
//        if self.playerListViewController == nil {
//            let vc = PlayerListViewController()
//            vc.view.frame = CGRect(x: 0, y: 0, width: max(250, self.view.frame.width * 0.3), height: max(200, self.view.frame.height * 0.5))
//            vc.delegate = self
//            self.playerListViewController = vc
//            self.present(vc, asPopoverRelativeTo: CGRect(x: 0, y: 0, width: 200, height: 200), of: controlView.playerListButton ?? view, preferredEdge: .minY, behavior: .transient)
//        }
    }
    
    private func hidePlayerList() {
//        if let vc = self.playerListViewController {
//            self.dismiss(vc)
//        }
    }
    
    private func showPlayerSetting() {
//        if self.playerSettingViewController == nil {
//            let vc = PlayerSettingViewController()
//
//            vc.view.frame = CGRect(x: 0, y: 0, width: max(400, self.view.frame.width * 0.3), height: max(400, self.view.frame.height * 0.5))
//            self.playerSettingViewController = vc
//            self.present(vc, asPopoverRelativeTo: CGRect(x: 0, y: 0, width: 200, height: 200), of: controlView.playerSettingButtoon ?? view, preferredEdge: .minY, behavior: .transient)
//        }
    }
    
    private func hidePlayerSetting() {
//        if let vc = self.playerSettingViewController {
//            self.dismiss(vc)
//        }
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
    
    private func autoShowControlView(completion: (() -> ())? = nil) {
        func startHiddenTimerAction() {
            self.autoHiddenTimer?.invalidate()
            
            self.autoHiddenTimer = Timer.scheduledTimer(withTimeInterval: 4, block: { (timer) in
                self.autoHideMouseControlView()
            }, repeats: false)
            self.autoHiddenTimer?.fireDate = Date(timeIntervalSinceNow: 4);
            
            completion?()
        }
        
        DispatchQueue.main.async {
            if self.hiddenControlView {
                self.hiddenControlView = false
                
//                var frame = self.controlView.frame
//                frame.origin.y = 0
//
//                NSAnimationContext.runAnimationGroup({ (context) in
//                    context.duration = 0.2;
//                    self.controlView.animator().frame = frame
//                }) {
//                    self.controlView.snp.remakeConstraints { (make) in
//                        make.top.equalTo(self.containerView.snp.bottom)
//                        make.leading.trailing.equalToSuperview()
//                        make.bottom.equalToSuperview()
//                    }
//
//                    startHiddenTimerAction()
//                }
            } else {
                startHiddenTimerAction();
            }
        }
    }
    
    private func autoHideMouseControlView() {
//        DispatchQueue.main.async {
//            //显示状态 隐藏
//            if self.hiddenControlView == false {
//                self.hiddenControlView = true
//                self.autoHiddenTimer?.invalidate()
//                NSCursor.setHiddenUntilMouseMoves(true)
//                var frame = self.controlView.frame
//                let height = self.controlView.frame.height > 0 ? self.controlView.frame.height : 70
//                let progressHeight: CGFloat = 15
//                frame.origin.y = -(height - progressHeight)
//
//                NSAnimationContext.runAnimationGroup({ (context) in
//                    context.duration = 0.2;
//                    self.controlView.animator().frame = frame
//                }) {
//                    self.controlView.snp.remakeConstraints { (make) in
//                        make.top.equalTo(self.containerView.snp.bottom)
//                        make.leading.trailing.equalToSuperview()
//                        make.bottom.equalToSuperview().offset(height - progressHeight)
//                    }
//                }
//            }
//        }
    }
    
    private func changeRepeatMode() {
        if let mode = DDPMediaPlayerRepeatMode(rawValue: UInt(Preferences.shared.playerMode.rawValue)) {
            player.repeatMode = mode
        }
    }
    
    //MARK: - PlayerListViewControllerDelegate
//    func currentPlayIndexAtPlayerListViewController(_ viewController: PlayerListViewController) -> Int? {
//        if let currentPlayItem = player.currentPlayItem {
//            return player.index(withItem: currentPlayItem)
//        }
//        return nil
//    }
//
//    func playerListViewController(_ viewController: PlayerListViewController, titleAtRow: Int) -> String {
//        return self.player.playerLists[titleAtRow].url?.lastPathComponent ?? ""
//    }
//
//    func playerListViewController(_ viewController: PlayerListViewController, didSelectedRow: Int) {
//        let item = self.player.playerLists[didSelectedRow]
//        if let playItem = findPlayItem(item) {
//            loadMediaItem(playItem)
//        }
//    }
//
//    func playerListViewController(_ viewController: PlayerListViewController, didDeleteRowIndexSet: IndexSet) {
//        player.removeMedia(with: didDeleteRowIndexSet)
//    }
//
//    func numberOfRowAtPlayerListViewController() -> Int {
//        return self.player.playerLists.count
//    }
    
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

//MARK: - PlayerUIViewDelegate
extension PlayerViewController: PlayerUIViewDelegate {
    func onTouchMoreButton(playerUIView: PlayerUIView) {
        
    }
    
    func onTouchPlayerList(playerUIView: PlayerUIView) {
        let manager = FileBrowerManager(multipleSelection: false)
        manager.delegate = self
        self.fileBrower = manager
        let animater = PlayerControlAnimater()
        objc_setAssociatedObject(manager, &FileBrowerManagerTransitioningKey, animater, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        manager.containerViewController.modalPresentationStyle = .custom
        manager.containerViewController.transitioningDelegate = animater
        self.present(manager.containerViewController, animated: true, completion: nil)
    }
    
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool) {
        self.danmakuRender.canvas.isHidden = !isOn
    }
    
    func doubleTap(playerUIView: PlayerUIView) {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat) {
        player.setPosition(progress) { [weak self] (time) in
            guard let self = self else {
                return
            }
            
            self.uiView.updateTime()
        }
    }
}

//MARK: - DDPMediaPlayerDelegate
extension PlayerViewController: DDPMediaPlayerDelegate {
    func mediaPlayer(_ player: DDPMediaPlayer, statusChange status: DDPMediaPlayerStatus) {
        switch status {
        case .playing:
            danmakuRender.start()
        case .pause, .stop:
            danmakuRender.pause()
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
        uiView.updateTime()
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
    
    func playerCurrentTime(playerUIView: PlayerUIView) -> TimeInterval {
        return player.currentTime
    }
    
    func playerTotalTime(playerUIView: PlayerUIView) -> TimeInterval {
        return player.length
    }
    
    func playerProgress(playerUIView: PlayerUIView) -> CGFloat {
        return player.position
    }
}

extension PlayerViewController: JHDanmakuEngineDelegate {
    //MARK: - JHDanmakuEngineDelegate
    func danmakuEngine(_ danmakuEngine: JHDanmakuEngine, didSendDanmakuAtTime time: UInt) -> [JHDanmakuProtocol] {
        return danmakuDic[time] ?? []
    }
}

extension PlayerViewController: FileBrowerManagerDelegate {
    func didSelectedPaths(manager: FileBrowerManager, paths: [String]) {
        let urls = paths.compactMap({ URL(fileURLWithPath: $0) })
        self.loadURLs(urls)
        self.fileBrower = nil
    }
    
    func didDismiss(manager: FileBrowerManager) {
        self.fileBrower = nil
    }
    
    func didCancel(manager: FileBrowerManager) {
        self.fileBrower = nil
    }
}
