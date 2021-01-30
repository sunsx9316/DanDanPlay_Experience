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
    
    private lazy var player: MediaPlayer = {
        let player = MediaPlayer()
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
        uiView.autoShowControlView()
        self.player(self.player, mediaDidChange: self.player.playList.first)
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
            
            let danmakus = message.danmakuCollection ?? DanmakuCollectionModel()
            let mediaId = message.mediaId
            let episodeId = message.episodeId
            
            let playItems = Array(self.playItemMap.values)
            if let item = playItems.first(where: { $0.mediaId == mediaId }) {
                item.playImmediately = message.playImmediately
                item.episodeId = episodeId
                danmakuCache.setObject(danmakus, forKey: NSNumber(value: episodeId))
                playMediaItem(item)
                uiView.titleLabel.text = message.title ?? item.url.lastPathComponent
            }
        case .syncSetting:
            guard let message = SyncSettingMessage.deserialize(from: data),
                  let enumValue = Preferences.KeyName(rawValue: message.key) else { break }
            
            switch enumValue {
            case .showDanmaku:
                self.danmakuRender.canvas.isHidden = !Preferences.shared.showDanmaku
            case .playerSpeed:
                let speed = CGFloat(Preferences.shared.playerSpeed)
                self.player.speed = speed
                self.danmakuRender.systemSpeed = speed
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
        case .loadCustomDanmaku:
            guard let _ = LoadCustomDanmakuMessage.deserialize(from: data) else { break }
            self.manager.dismissSetting {
                self.manager.showDanmakuFileBrower(from: self)
            }
        default:
            break
        }
    }
    
    func loadURLs(_ urls: [URL]) {
        for url in urls {
            if self.playItemMap[url] == nil {
                let item = PlayItem(url: url)
                self.playItemMap[url] = item
                self.player.addMediaToPlayList(item)
            }
        }
    }
    
    //MARK: - Private
    
    private func changeVolume(_ addBy: CGFloat) {
        self.player.volume += Int(addBy)
    }
    
    private func playMediaItem(_ item: PlayItem) {
        self.player.play(item)
    }
    
    @objc private func onClickPlayButton() {
        if self.player.isPlaying {
            self.player.pause()
        } else {
            self.player.play()
        }
    }
    
    private func findPlayItem(_ protocolItem: DDPMediaPlayer.MediaItem) -> PlayItem? {
        if let protocolItem = protocolItem as? PlayItem {
            return protocolItem
        }
        
        return self.playItemMap[protocolItem.url]
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
    
    private func setPlayerProgress(_ progress: CGFloat) {
        _ = self.player.setPosition(progress)
        self.danmakuRender.currentTime = self.player.currentTime
        self.uiView.updateTime()
    }
}

extension PlayerViewController {
    private class PlayItem: NSObject, MediaItem {
        
        var url: URL
        var option: [AnyHashable : Any]?
        var playImmediately = false
        
        var mediaId: String {
            return url.path
        }
        var episodeId = 0
        
        init(url: URL) {
            self.url = url
            super.init()
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
        self.setPlayerProgress(progress)
    }
    
    func changeProgress(playerUIView: PlayerUIView, diffValue: CGFloat) {
        let length = self.player.length
        if length > 0 {
            let progress = (CGFloat(self.player.currentTime) + diffValue) / CGFloat(length)
            self.setPlayerProgress(progress)
        }
    }
    
    func changeBrightness(playerUIView: PlayerUIView, diffValue: CGFloat) {
        
    }
    
    func changeVolume(playerUIView: PlayerUIView, diffValue: CGFloat) {
        self.player.volume += Int(diffValue)
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

//MARK: - MediaPlayerDelegate
extension PlayerViewController: MediaPlayerDelegate {
    
    func player(_ player: MediaPlayer, stateDidChange state: MediaPlayer.State) {
        switch state {
        case .playing:
            danmakuRender.start()
            self.uiView.playButton.isSelected = true
        case .pause, .stop:
            danmakuRender.pause()
            self.uiView.playButton.isSelected = false
        }
    }
    
    func player(_ player: MediaPlayer, mediaDidChange media: MediaItem?) {
        
        guard let media = media,
            let item = findPlayItem(media) else { return }
        
        let danmakuCollection = self.danmakuCache.object(forKey: NSNumber(value: item.episodeId))
        
        if danmakuCollection != nil || item.playImmediately {
            let danmakus = danmakuCollection?.collection ?? []
            self.danmakuDic = DanmakuManager.shared.conver(danmakus)
            self.danmakuRender.currentTime = 0
            self.player.play(item)
        } else {
            //请求完弹幕再播放
            let url = item.url
            
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
                            let everyReadSize = 1024
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
    
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        uiView.updateTime()
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
    
    func didSelectedDanmakuURLs(urls: [URL]) {
        guard let url = urls.first else { return }
        
        DispatchQueue.global().async {
            
            let shouldStop = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStop {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            var error: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, error: &error) { (aURL) in
                if let data = try? Data(contentsOf: aURL), let dic = NSDictionary(xml: data) {
                    if let arr = dic["d"] as? [[String : Any]] {
                        var danmakuModels = [DanmakuModel]()
                        for d in arr {
                            if let p = d["p"] as? String {
                                let strArr = p.components(separatedBy: ",")
                                if strArr.count >= 4, let text = d["_text"] as? String {
                                    let model = DanmakuModel()
                                    model.time = TimeInterval(strArr[0]) ?? 0
                                    model.mode = DanmakuModel.Mode(rawValue: Int(strArr[1]) ?? 1) ?? .normal
                                    model.color = UIColor(rgb: Int(strArr[3]) ?? 0)
                                    model.message = text
                                    danmakuModels.append(model)
                                }
                            }
                        }
                        
                        let converDic = DanmakuManager.shared.conver(danmakuModels)
                        DispatchQueue.main.async {
                            self.danmakuDic = converDic
                            self.setPlayerProgress(0)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        if let error = error {
                            self.view.showHUD("加载自定义弹幕失败：\(error.localizedDescription)")
                        } else {
                            self.view.showHUD("加载自定义弹幕失败")
                        }
                    }
                }
            }
        }
        
    }
}


