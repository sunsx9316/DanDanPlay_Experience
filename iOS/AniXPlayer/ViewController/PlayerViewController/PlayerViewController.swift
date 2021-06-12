//
//  PlayerViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/26.
//

import UIKit
import JHDanmakuRender
import SnapKit
import YYCategories
import MBProgressHUD

class PlayerViewController: ViewController {
    
    private let kShortJumpValue: Int32 = 5
    
    private let kVolumeAddingValue: CGFloat = 20
    
    private lazy var uiView: PlayerUIView = {
        let view = PlayerUIView()
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
        danmakuRender.canvas.isHidden = !Preferences.shared.isShowDanmaku
        danmakuRender.offsetTime = TimeInterval(Preferences.shared.danmakuOffsetTime)
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
    
    private lazy var animater = PlayerControlAnimater()
    
    /// 初始化时选择的视频
    private var selectedItem: File?
    
    //MARK: - life cycle
    
    init(items: [File], selectedItem: File? = nil) {
        super.init(nibName: nil, bundle: nil)
        
        Helper.shared.playerViewController = self
        
        self.selectedItem = selectedItem
        loadItems(items)
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
        
        if let selectedItem = self.selectedItem {
            self.tryParseMedia(selectedItem)
            self.selectedItem = nil
        } else if let firstItem = self.player.playList.first {
            self.tryParseMedia(firstItem)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        if self.isViewLoaded == false {
            return false
        }
        return self.uiView.hiddenControlView
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
    
    
    //MARK: - Private
    private func loadItems(_ items: [File]) {
        for item in items {
            
            if item.type == .folder {
                continue
            }
            
            let url = item.url
            if self.playItemMap[url] == nil {
                let playItem = PlayItem(item: item)
                self.playItemMap[url] = playItem
                self.player.addMediaToPlayList(item)
            }
        }
    }
    
    private func changeVolume(_ addBy: CGFloat) {
        self.player.volume += Int(addBy)
    }
    
    private func findPlayItem(_ protocolItem: File) -> PlayItem? {
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
        let currentTime = self.player.setPosition(Double(progress))
        self.danmakuRender.currentTime = currentTime
        self.uiView.updateTime()
    }
    
    private func tryParseMedia(_ media: File) {
        self.player.stop()
        
        self.uiView.title = media.fileName
        
        let hud = self.view.showProgress()
        hud.label.text = "解析视频中..."
        hud.progress = 0
        hud.show(animated: true)
        
        NetworkManager.shared.danmakuWithFile(media) { (progress) in
            DispatchQueue.main.async {
                hud.progress = Float(progress)
                if progress == 0.7 {
                    hud.label.text = "加载弹幕中..."
                }
            }
        } matchCompletion: { (collection, error) in
            DispatchQueue.main.async {
                hud.hide(animated: true)
                
                if let error = error {
                    self.view.showError(error)
                } else if let collection = collection {
                    let vc = MatchsViewController(with: collection, file: media)
                    vc.delegate = self
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        } danmakuCompletion: { (collection, error) in
            DispatchQueue.main.async {
                hud.hide(animated: true)
                
                if let error = error {
                    self.view.showError(error)
                } else {
                    let danmakus = collection?.collection ?? []
                    self.playMedia(media, danmakus: danmakus)
                }
            }
        }
    }
    
    private func playMedia(_ media: File, danmakus: [Comment]) {
        
        let startPlayAction = { [weak self] (_ comment: [UInt : [JHDanmakuProtocol]]) in
            guard let self = self else { return }
            
            self.danmakuDic = comment
            self.danmakuRender.currentTime = 0
            self.player.play(media)
        }
        
        //加载本地弹幕
        if Preferences.shared.autoLoadCustomDanmaku {
            DanmakuManager.shared.loadCustomDanmakuWithMedia(media) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let url):
                    do {
                        let converResult = try DanmakuManager.shared.conver(url)
                        DispatchQueue.main.async {
                            startPlayAction(converResult)
                            self.view.showHUD(NSLocalizedString("加载本地弹幕成功！", comment: ""))
                        }
                    } catch let error {
                        DispatchQueue.main.async {
                            startPlayAction(DanmakuManager.shared.conver(danmakus))
                            self.view.showError(error)
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        startPlayAction(DanmakuManager.shared.conver(danmakus))
                        
                        //不存在的错误不用展示tips
                        if let error = error as? DanmakuError,
                           error == DanmakuError.customDanmakuNotExit {
                            return
                        }
                        self.view.showError(error)
                    }
                }
            }
        } else {
            startPlayAction(DanmakuManager.shared.conver(danmakus))
        }
        
        //加载本地字幕
        SubtitleManager.shared.loadCustomSubtitleWithMedia(media) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let url):
                DispatchQueue.main.async {
                    self.view.showHUD(NSLocalizedString("加载本地字幕成功！", comment: ""))
                    self.player.openVideoSubTitle(with: url)
                }
            case .failure(let error):
                
                //不存在的错误不用展示tips
                if let error = error as? SubtitleError,
                   error == SubtitleError.customSubtitleNotExit {
                    return
                }
                
                DispatchQueue.main.async {
                    self.view.showError(error)
                }
            }
        }
    }
    
    /// 弹出文件选择器
    /// - Parameter type: 筛选文件类型
    func showFilesVCWithType(_ type: FilesViewController.FilterType) {
        
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        let item = self.player.currentPlayItem ?? self.player.playList.first
        
        if let parentFile = item?.parentFile {
            let vc = FilesViewController(with: parentFile, selectedFile: item, filterType: type)
            vc.delegate = self
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .custom
            nav.transitioningDelegate = self.animater
            self.present(nav, animated: true, completion: nil)
        }
    }
}

extension PlayerViewController: MatchsViewControllerDelegate {
    
    func matchsViewController(_ matchsViewController: MatchsViewController, didSelectedEpisodeId episodeId: Int) {
        
        matchsViewController.navigationController?.popToRootViewController(animated: true)
        
        NetworkManager.shared.danmakuWithEpisodeId(episodeId) { [weak self] (collection, error) in
            
            guard let self = self else { return }
            
            if let error = error {
                self.view.showError(error)
            } else {
                let danmakus = collection?.collection ?? []
                self.playMedia(matchsViewController.file, danmakus: danmakus)
            }
        }
    }
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController) {
        matchsViewController.navigationController?.popToRootViewController(animated: true)
        self.playMedia(matchsViewController.file, danmakus: [])
    }
}

extension PlayerViewController {
    private class PlayItem {
  
        private let media: File
        var playImmediately = false
        var mediaId: String {
            return self.media.url.path
        }
        
        var episodeId = 0
        
        init(item: File) {
            self.media = item
        }
    }
}

extension PlayerViewController: PlayerUIViewDelegate, PlayerUIViewDataSource {
    //MARK: PlayerUIViewDelegate
    func onTouchMoreButton(playerUIView: PlayerUIView) {
        let vc = PlayerSettingViewController(player: self.player)
        vc.delegate = self
        vc.transitioningDelegate = self.animater
        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = animater
        self.present(vc, animated: true, completion: nil)
    }
    
    func onTouchPlayerList(playerUIView: PlayerUIView) {
        self.showFilesVCWithType(.video)
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
        
        let vc = SendDanmakuViewController()
        vc.onTouchSendButtonCallBack = { [weak self] (text, aVC) in
            guard let self = self else { return }
            
            guard let item = self.player.currentPlayItem,
                  let episodeId = self.findPlayItem(item)?.episodeId else {
                
                self.view.showHUD("需要指定视频弹幕列表，才能发弹幕哟~")
                return
            }
            
//            if !text.isEmpty {
//                let danmaku = DanmakuModel()
//                danmaku.mode = .normal
//                danmaku.time = self.danmakuRender.currentTime + self.danmakuRender.offsetTime
//                danmaku.message = text
//                danmaku.id = "\(Date().timeIntervalSince1970)"
//
//                let msg = SendDanmakuMessage()
//                msg.danmaku = danmaku
//                msg.episodeId = episodeId
//                #warning("待处理")
////                MessageHandler.sendMessage(msg)
//
////                self.danmakuRender.sendDanmaku(DanmakuManager.shared.conver(danmaku))
//            }
            
            aVC.navigationController?.popViewController(animated: true)
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func onTouchPlayButton(playerUIView: PlayerUIView, isSelected: Bool) {
        if self.player.isPlaying {
            self.player.pause()
            self.showPauseHUD()
        } else {
            self.player.play()
        }
    }
    
    func onTouchNextButton(playerUIView: PlayerUIView) {
        if let index = self.player.playList.firstIndex(where: { $0.url == self.player.currentPlayItem?.url }) {
            if index != self.player.playList.count - 1 {
                let item = self.player.playList[index + 1]
                self.tryParseMedia(item)
            }
        }
    }
    
    func doubleTap(playerUIView: PlayerUIView) {
        if player.isPlaying {
            player.pause()
            self.showPauseHUD()
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
        return CGFloat(player.position)
    }
    
    func playerUIView(_ playerUIView: PlayerUIView, didChangeControlViewState show: Bool) {
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    private func showPauseHUD() {
        let view = MBProgressHUD.showAdded(to: self.view, animated: true)
        view.mode = .customView
        view.bezelView.color = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        view.bezelView.style = .solidColor
        view.label.font = .ddp_normal
        view.label.numberOfLines = 0
        view.contentColor = .white
        view.isUserInteractionEnabled = true
        
        let imgView = UIImageView()
        imgView.image = UIImage(named: "Player/player_pause")
        view.customView = imgView
        view.hide(animated: true, afterDelay: 0.8)
    }
}

//MARK: - MediaPlayerDelegate
extension PlayerViewController: MediaPlayerDelegate {
    
    func player(_ player: MediaPlayer, stateDidChange state: MediaPlayer.State) {
        switch state {
        case .playing:
            danmakuRender.start()
            self.uiView.isPlay = true
        case .pause, .stop:
            danmakuRender.pause()
            self.uiView.isPlay = false
        }
    }
    
    func player(_ player: MediaPlayer, shouldChangeMedia media: File) -> Bool {
        
        self.tryParseMedia(media)
        
        return false
    }
    
    func player(_ player: MediaPlayer, mediaDidChange media: File?) {
        
        
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


extension PlayerViewController: DanmakuSettingViewControllerDelegate {
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuAlpha alpha: Float) {
        danmakuRender.canvas.alpha = CGFloat(alpha)
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuSpeed speed: Float) {
        danmakuRender.systemSpeed = CGFloat(speed)
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuFontSize fontSize: Double) {
        let danmakuFontSize = CGFloat(fontSize)
        danmakuRender.globalFont = UIFont.systemFont(ofSize: danmakuFontSize)
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuCount count: Int) {
        danmakuRender.limitCount = UInt(count == Preferences.shared.danmakuUnlimitCount ? 0 : count)
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeShowDanmaku isShow: Bool) {
        self.danmakuRender.canvas.isHidden = !isShow
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuOffsetTime danmakuOffsetTime: Int) {
        self.danmakuRender.offsetTime = TimeInterval(danmakuOffsetTime)
    }
    
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        self.showFilesVCWithType(.danmaku)
    }
}

extension PlayerViewController: MediaSettingViewControllerDelegate {
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangeSubtitleSafeArea isOn: Bool) {
        
        UIView.animate(withDuration: 0.2) {
            let mainColor = UIColor.mainColor
            let backgroundColor = UIColor(red: mainColor.red, green: mainColor.green, blue: mainColor.green, alpha: 0.3)
            self.danmakuRender.canvas.backgroundColor = backgroundColor
            
        } completion: { (_) in
            UIView.animate(withDuration: 0.1) {
                self.danmakuRender.canvas.backgroundColor = .clear
            }
        }

        self.danmakuRender.canvas.snp.remakeConstraints { (make) in
            make.top.leading.trailing.equalTo(self.containerView)
            if isOn {
                make.height.equalTo(self.containerView).multipliedBy(0.85)
            } else {
                make.height.equalTo(self.containerView)
            }
        }
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangePlayerSpeed speed: Double) {
        self.player.speed = speed
        self.danmakuRender.systemSpeed = CGFloat(speed)
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangePlayerMode mode: Preferences.PlayerMode) {
        self.changeRepeatMode()
    }
    
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController) {
        self.showFilesVCWithType(.subtitle)
    }
    
}

extension PlayerViewController: FilesViewControllerDelegate {
    func filesViewController(_ vc: FilesViewController, didSelectFile: File, allFiles: [File]) {
        
        if didSelectFile.url.isMediaFile {
            self.loadItems(allFiles)
            self.tryParseMedia(didSelectFile)
            vc.dismiss(animated: true, completion: nil)
        } else if didSelectFile.url.isDanmakuFile {
            DispatchQueue.global().async {
                do {
                    let converDic = try DanmakuManager.shared.conver(didSelectFile.url)
                    DispatchQueue.main.async {
                        self.danmakuDic = converDic
                        vc.dismiss(animated: true, completion: nil)
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        self.view.showError(error)
                        vc.dismiss(animated: true, completion: nil)
                    }
                }
            }
        } else if didSelectFile.url.isSubtitleFile {
            self.player.openVideoSubTitle(with: didSelectFile.url)
            vc.dismiss(animated: true, completion: nil)
        }
    }
}
