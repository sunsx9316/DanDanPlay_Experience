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

class PlayerViewController: UIViewController {
    
    private let kShortJumpValue: Int32 = 5
    private let kVolumeAddingValue: CGFloat = 20
    
    private lazy var uiView: PlayerUIView = {
        let view = PlayerUIView.fromNib()
        view.delegate = self
        view.dataSource = self
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var danmakuRender: JHDanmakuEngine = {
        let danmakuRender = JHDanmakuEngine()
        danmakuRender.delegate = self
        danmakuRender.setUserInfoWithKey(JHScrollDanmakuExtraSpeedKey, value: 1)
        
        danmakuRender.globalFont = UIFont.systemFont(ofSize: CGFloat(Preferences.shared.danmakuFontSize))
        danmakuRender.systemSpeed = CGFloat(Preferences.shared.danmakuSpeed)
        danmakuRender.canvas.alpha = CGFloat(Preferences.shared.danmakuAlpha)
        danmakuRender.canvas.isHidden = !Preferences.shared.showDanmaku
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
    
    private lazy var manager: PlayerManager = {
        let manager = PlayerManager()
        manager.delegate = self
        return manager
    }()
    
    
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if self.player.isPlaying {
            self.player.pause()
        }
    }
    
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
//        autoShowControlView()
        uiView.autoShowControlView()
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
            guard let message = LoadDanmakuMessage.deserialize(from: data) else { break }
            
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
        case .syncSetting:
            guard let message = SyncSettingMessage.deserialize(from: data),
                  let enumValue = Preferences.KeyName(rawValue: message.key) else { break }
            
            switch enumValue {
            case .showDanmaku:
                self.danmakuRender.canvas.isHidden = !Preferences.shared.showDanmaku
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
        case .reloadMatch:
            guard let message = ReloadMatchWidgetMessage.deserialize(from: data) else { break }
            
            let vc = MatchMessageViewController(with: message)
            vc.parseMessageCallBack = { [weak self] (name, data) in
                guard let self = self else { return }
                
                self.parseMessage(name, data: data)
            }
            vc.reloadData(message)
            self.navigationController?.pushViewController(vc, animated: true)
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
    
    private func findPlayItem(_ protocolItem: DDPMediaItemProtocol) -> PlayItem? {
        if let protocolItem = protocolItem as? PlayItem {
            return protocolItem
        }
        
        if let url = protocolItem.url {
            return self.playItemMap[url]
        }
        
        return nil
    }
    
    private func changeRepeatMode() {
        if let mode = DDPMediaPlayerRepeatMode(rawValue: UInt(Preferences.shared.playerMode.rawValue)) {
            player.repeatMode = mode
        }
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

extension PlayerViewController: PlayerUIViewDelegate, PlayerUIViewDataSource {
    //MARK: PlayerUIViewDelegate
    func onTouchMoreButton(playerUIView: PlayerUIView) {
        self.manager.showSetting(from: self)
    }
    
    func onTouchPlayerList(playerUIView: PlayerUIView) {
        self.manager.showFileBrower(from: self)
    }
    
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool) {
        self.danmakuRender.canvas.isHidden = !isOn
    }
    
    func onTouchSendDanmakuButton(playerUIView: PlayerUIView) {
        guard let item = self.player.currentPlayItem,
              self.findPlayItem(item)?.episodeId != nil else {
            self.view.showHUD("需要指定视频弹幕列表，才能发弹幕哟~")
            return
        }
        
        let vc = SendDanmakuViewController(project: nil, nibName: nil, bundle: nil)
        vc.onTouchSendButtonCallBack = { [weak self] (text, aVC) in
            guard let self = self else { return }
            
            guard let item = self.player.currentPlayItem,
                  let episodeId = self.findPlayItem(item)?.episodeId else {
                
                self.view.showHUD("需要指定视频弹幕列表，才能发弹幕哟~")
                return
            }
            
            if !text.isEmpty {
                let danmaku = DanmakuModel()
                danmaku.mode = .normal
                danmaku.time = self.danmakuRender.currentTime + self.danmakuRender.offsetTime
                danmaku.message = text
                danmaku.id = "\(Date().timeIntervalSince1970)"
                
                let msg = SendDanmakuMessage()
                msg.danmaku = danmaku
                msg.episodeId = episodeId
                MessageHandler.sendMessage(msg)
                
                self.danmakuRender.sendDanmaku(DanmakuManager.shared.conver(danmaku))
            }
            
            aVC.navigationController?.popViewController(animated: true)
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func onTouchPlayButton(playerUIView: PlayerUIView, isSelected: Bool) {
        if self.player.isPlaying {
            self.player.pause()
        } else {
            self.player.play()
        }
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
    
    func changeProgress(playerUIView: PlayerUIView, diffValue: CGFloat) {
        player.jump(Int32(diffValue)) { [weak self] (time) in
            guard let self = self else {
                return
            }
            
            self.uiView.updateTime()
        }
    }
    
    func changeBrightness(playerUIView: PlayerUIView, diffValue: CGFloat) {
        
    }
    
    func changeVolume(playerUIView: PlayerUIView, diffValue: CGFloat) {
        player.volumeJump(diffValue)
    }
    
    //MARK: PlayerUIViewDataSource
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

//MARK: - DDPMediaPlayerDelegate
extension PlayerViewController: DDPMediaPlayerDelegate {
    func mediaPlayer(_ player: DDPMediaPlayer, statusChange status: DDPMediaPlayerStatus) {
        switch status {
        case .playing:
            danmakuRender.start()
            self.uiView.playButton.isSelected = true
        case .pause, .stop:
            danmakuRender.pause()
            self.uiView.playButton.isSelected = false
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
            if let url = item.url {
                self.player.pause()
                
                let message = ParseFileMessage()
                message.mediaId = item.mediaId
                
                let hud = self.view.showProgress()
                hud.label.text = "解析视频中..."
                hud.progress = 0
                
                DispatchQueue.global().async {
                    let shouldStop = url.startAccessingSecurityScopedResource()
                    defer {
                        if shouldStop {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    var error: NSError?
                    NSFileCoordinator().coordinate(readingItemAt: url, error: &error) { (aURL) in
                        do {
                            let attributesOfItem = try FileManager.default.attributesOfItem(atPath:aURL.path)
                            let size = attributesOfItem[.size] as? Int ?? 0
                            message.fileSize = size
                            
                            if let fileHandle = try? FileHandle(forReadingFrom: aURL) {
                                var seek: UInt64 = 0
                                var allData = Data()
                                let readSize = min(16777216, size)
                                let everyReadSize = 512
                                while seek < readSize {
                                    allData.append(fileHandle.readData(ofLength: everyReadSize))
                                    fileHandle.seek(toFileOffset: seek)
                                    seek += UInt64(everyReadSize)
                                    
                                    let progress = readSize == 0 ? 0 : Float(seek) / Float(readSize)
                                    DispatchQueue.main.async {
                                        hud.progress = progress
                                    }
                                }
                                
                                message.fileHash = (allData as NSData).md5String()
                            }
                            
                            if let data = try? FileHandle(forReadingFrom: aURL).readData(ofLength: min(16777216, size)) as NSData {
                                message.fileHash = data.md5String()
                            }
                            
                            message.fileName = aURL.deletingPathExtension().lastPathComponent
                            DispatchQueue.main.async {
                                MessageHandler.sendMessage(message)
                                hud.hide(animated: true)
                            }
                        } catch let error {
                            DispatchQueue.main.async {
                                hud.hide(animated: true)
                                self.view.showHUD(error.localizedDescription)
                            }
                        }
                    }
                }
            }
        }
    }
}

//MARK: - JHDanmakuEngineDelegate
extension PlayerViewController: JHDanmakuEngineDelegate {
    func danmakuEngine(_ danmakuEngine: JHDanmakuEngine, didSendDanmakuAtTime time: UInt) -> [JHDanmakuProtocol] {
        return danmakuDic[time] ?? []
    }
}

//MARK: PlayerManagerDelegate
extension PlayerViewController: PlayerManagerDelegate {
    func didSelectedURLs(urls: [URL]) {
        self.loadURLs(urls)
    }
}


