//
//  PlayerViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/26.
//

import UIKit
import DanmakuRender
import SnapKit
import YYCategories
import MBProgressHUD
import DynamicButton

private class PlayItem {
    
    var watchProgressKey: String? {
        if episodeId != 0 {
            return "\(episodeId)"
        }
        return media.fileHash
    }
    
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
    
    private lazy var danmakuRender: DanmakuEngine = {
        let danmakuRender = DanmakuEngine()
        danmakuRender.layoutStyle = .nonOverlapping
        return danmakuRender
    }()
    
    /// 弹幕画布容器
    private lazy var danmakuCanvas: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var player: MediaPlayer = {
        let player = MediaPlayer(coreType: .vlc)
        player.delegate = self
        return player
    }()
    
    private var playItemMap = [URL : PlayItem]()
    //当前弹幕时间/弹幕数组映射
    private var danmakuDic = DanmakuMapResult()
    
    /// 记录当前屏幕展示的弹幕
    private lazy var danmuOnScreenMap = NSMapTable<NSString, BaseDanmaku>.strongToWeakObjects()
    
    private lazy var animater = PlayerControlAnimater()
    
    /// 初始化时选择的视频
    private var selectedItem: File?
    
    ///加速指示器
    private weak var speedUpHUD: MBProgressHUD?
    
    ///开启临时加速前的速度
    private var originSpeed: Double?
    
    /// 当前弹幕的时间
    private var danmakuTime: UInt?
    
    /// 弹幕字体
    private lazy var danmakuFont = UIFont.systemFont(ofSize: CGFloat(Preferences.shared.danmakuFontSize))
    
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
    
    deinit {
        self.storeProgress()
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
        
        self.storeProgress()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.player.mediaView)
        self.containerView.addSubview(self.danmakuCanvas)
        self.view.addSubview(self.uiView)
        self.danmakuCanvas.addSubview(self.danmakuRender.canvas)
        
        self.containerView.snp.makeConstraints { (make) in
            make.top.leading.trailing.bottom.equalTo(self.view)
        }
        
        self.player.mediaView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.containerView)
        }
        
        self.uiView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.applyPreferences()
        
        changeRepeatMode()
        uiView.autoShowControlView()
        
        parseMediaAtInit()
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
    /// 在初始化时尝试解析视频
    private func parseMediaAtInit() {
        if let selectedItem = self.selectedItem {
            self.tryParseMedia(selectedItem)
            self.selectedItem = nil
        } else if let firstItem = self.player.playList.first {
            self.tryParseMedia(firstItem)
        }
    }
    
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
        self.danmakuRender.time = currentTime
        self.uiView.updateTime()
    }
    
    private func setPlayerProgress(diffValue: CGFloat, from: CGFloat? = nil) {
        let length = self.player.length
        
        let fromValue = from ?? CGFloat(self.player.currentTime)
        
        if length > 0 {
            let progress = (fromValue + diffValue) / CGFloat(length)
            self.setPlayerProgress(progress)
        }
    }
    
    private func tryParseMedia(_ media: File) {
        
        self.storeProgress()
        
        self.player.stop()
        
        self.uiView.title = media.fileName
        
        let hud = self.view.showProgress()
        hud.label.text = "解析视频中..."
        hud.progress = 0
        hud.show(animated: true)
        
        DanmakuManager.shared.loadDanmaku(media) { progress in
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
        } danmakuCompletion: { result, episodeId, error in
            DispatchQueue.main.async {
                hud.hide(animated: true)
                
                if let error = error {
                    self.view.showError(error)
                } else {
                    self.startPlay(media, episodeId: episodeId, danmakus: result ?? [:])
                }
            }
        }

    }
    
    
    
    /// 开始播放
    /// - Parameters:
    ///   - media: 视频
    ///   - episodeId: 弹幕分级id
    ///   - danmakus: 弹幕
    private func startPlay(_ media: File, episodeId: Int, danmakus: DanmakuMapResult) {
        
        self.danmakuDic = danmakus
        self.danmakuRender.time = 0
        self.danmakuTime = nil
        self.player.play(media)
        
        self.loadSubtitle(media)
        let loadLastWatchProgressSuccess = self.loadLastWatchProgress(media, episodeId: episodeId)
        if !loadLastWatchProgressSuccess {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.autoJumpTitle()
            }
        }
    }
    
    
    /// 加载外挂字幕
    private func loadSubtitle(_ media: File) {
        SubtitleManager.shared.loadLocalSubtitle(media) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let subtitle):
                self.player.currentSubtitle = subtitle
                self.view.showHUD(NSLocalizedString("加载字幕成功！", comment: ""))
            case .failure(_):
                break
            }
        }
    }
    
    /// 定位上次播放的位置
    private func loadLastWatchProgress(_ media: File, episodeId: Int) -> Bool {
        if let playItem = self.findPlayItem(media) {
            playItem.episodeId = episodeId
            if let watchProgressKey = playItem.watchProgressKey,
               let lastWatchProgress = HistoryManager.shared.watchProgress(mediaKey: watchProgressKey) {
                
                if lastWatchProgress > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        
                        func lastTimeString() -> String {
                            let timeFormatter = DateFormatter()
                            timeFormatter.dateFormat = "mm:ss"
                            return timeFormatter.string(from: Date(timeIntervalSince1970: self.player.length * lastWatchProgress))
                        }
                        
                        let customView = GotoLastWatchPointView()
                        customView.timeString = NSLocalizedString("上次观看时间：", comment: "") + lastTimeString()
                        customView.didClickGotoButton = { [weak self] in
                            guard let self = self else { return }
                            
                            self.setPlayerProgress(lastWatchProgress)
                            self.uiView.autoShowControlView()
                        }
                        
                        customView.show(from: self.view)
                    }
                    
                    return true
                }
            }
        }
        
        return false
    }
    
    private func autoJumpTitle() {
        if Preferences.shared.autoJumpTitleEnding {
            let duration = Preferences.shared.jumpTitleDuration
            
            if duration > 0 && self.player.length > 0 && duration < self.player.length {
                self.setPlayerProgress(diffValue: duration, from: 0)
            }
        }
    }
    
    private func autoJumpEnding() {
        if Preferences.shared.autoJumpTitleEnding {
            let duration = Preferences.shared.jumpEndingDuration
            
            if duration > 0 && self.player.length > 0 {
                
                let shouldJumpEnding = self.player.currentTime + duration >= self.player.length &&
                duration < self.player.length &&
                self.player.length - self.player.currentTime > 2
                
                if shouldJumpEnding {
                    self.setPlayerProgress(diffValue: self.player.length - 1, from: 0)
                }
            }
        }
    }
    
    /// 弹出文件选择器
    /// - Parameter type: 筛选文件类型
    private func showFilesVCWithType(_ type: URLFilterType) {
        
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        let item = self.player.currentPlayItem ?? self.player.playList.first
        
        if let parentFile = item?.parentFile {
            let vc = FileBrowserViewController(with: parentFile, selectedFile: item, filterType: type)
            vc.delegate = self
            let nav = NavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .custom
            nav.transitioningDelegate = self.animater
            self.present(nav, animated: true, completion: nil)
        }
    }
    
    //保存观看记录
    private func storeProgress() {
        if let currentPlayItem = self.player.currentPlayItem,
           let playItem = self.findPlayItem(currentPlayItem),
            let watchProgressKey = playItem.watchProgressKey {
            
            let position = self.player.position
            //播放结束不保存进度
            if position >= 0.99 {
                HistoryManager.shared.cleanWatchProgress(mediaKey: watchProgressKey)
            } else {
                HistoryManager.shared.storeWatchProgress(mediaKey: watchProgressKey, progress: position)
            }
        }
    }
    
    /// 调整播放器和弹幕整体
    /// - Parameter speed: 速度
    private func changeSpeed(_ speed: Double) {
        self.player.speed = speed
        self.danmakuRender.speed = speed
    }
    
    /// 重新布局弹幕画布
    private func layoutDanmakuCanvas() {
        self.danmakuCanvas.snp.remakeConstraints { (make) in
            make.top.leading.trailing.equalTo(self.containerView)
            if Preferences.shared.subtitleSafeArea {
                make.height.equalTo(self.containerView).multipliedBy(0.85)
            } else {
                make.height.equalTo(self.containerView)
            }
        }
        
        self.danmakuRender.canvas.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            let danmakuProportion = Preferences.shared.danmakuProportion
            make.height.equalToSuperview().multipliedBy(danmakuProportion)
        }
    }
    
    /// 应用偏好设置
    private func applyPreferences() {
        self.danmakuCanvas.alpha = CGFloat(Preferences.shared.danmakuAlpha)
        self.danmakuCanvas.isHidden = !Preferences.shared.isShowDanmaku
        self.danmakuFont = UIFont.systemFont(ofSize: CGFloat(Preferences.shared.danmakuFontSize))
        self.danmakuRender.offsetTime = TimeInterval(Preferences.shared.danmakuOffsetTime)
        self.changeSpeed(Preferences.shared.playerSpeed)
        self.layoutDanmakuCanvas()
    }
    
    
    /// 播放 / 暂停
    private func playOrPauseStateChange() {
        
        if self.player.currentPlayItem != nil {
            if self.player.isPlaying {
                self.player.pause()
                self.showPauseHUD()
            } else {
                self.player.play()
            }
        } else {
            /// 当前没有播放的对象，尝试解析视频
            self.parseMediaAtInit()
        }
    }
    
    
    /// 发送弹幕
    private func sendDanmakus(at currentTime: TimeInterval) {
        let danmakuRenderTime = currentTime + self.danmakuRender.offsetTime
        
        if danmakuRenderTime < 0 {
            return
        }
        
        let intTime = UInt(danmakuRenderTime)
        /// 一秒只发射一次弹幕
        if intTime == self.danmakuTime {
            return
        }
        
        self.danmakuTime = intTime
        if let danmakus = danmakuDic[intTime] {
            let danmakuDensity = Preferences.shared.danmakuDensity
            for danmakuBlock in danmakus {
                /// 小于弹幕密度才允许发射
                let shouldSendDanmaku = Float.random(in: 0...10) <= danmakuDensity
                if shouldSendDanmaku {
                    let danmaku = danmakuBlock()
                    
                    /// 修复因为时间误差的问题，导致少数弹幕突然出现在屏幕上的问题
                    if danmaku.appearTime > 0 {
                        danmaku.appearTime = self.danmakuRender.time + (danmaku.appearTime - Double(intTime))
                    }
                    
                    /// 合并弹幕启用时，查找屏幕上与本弹幕文案相同的弹幕，进行更新
                    if Preferences.shared.isMergeSameDanmaku {
                        let danmakuTextKey = danmaku.text as NSString

                        /// 文案与当前弹幕相同
                        if let oldDanmaku = self.danmuOnScreenMap.object(forKey: danmakuTextKey) as? DanmakuEntity {
                            oldDanmaku.repeatDanmakuInfo?.repeatCount += 1
                            self.danmakuRender.update(oldDanmaku)
                        } else {
                            danmaku.repeatDanmakuInfo = .init(danmaku: danmaku)
                            
                            self.danmakuRender.send(danmaku)
                            self.danmuOnScreenMap.setObject(danmaku, forKey: danmakuTextKey)
                        }
                    } else {
                        self.danmakuRender.send(danmaku)
                    }
                    
                }
            }
        }
    }
}

extension PlayerViewController: MatchsViewControllerDelegate {
    // MARK: - MatchsViewControllerDelegate
    
    func matchsViewController(_ matchsViewController: MatchsViewController, didSelectedEpisodeId episodeId: Int) {
        
        switch matchsViewController.style {
        case .full:
            matchsViewController.navigationController?.popToRootViewController(animated: true)
        case .mini:
            if let presentedViewController = self.presentedViewController {
                presentedViewController.dismiss(animated: true, completion: nil)
            }
        }
        
        let hud = self.view.showProgress()
        hud.label.text = "加载弹幕中..."
        hud.progress = 0.5
        hud.show(animated: true)

        CommentNetworkHandle.getDanmaku(with: episodeId) { [weak self] (collection, error) in
            
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    hud.progress = 1
                    hud.hide(animated: true)
                    self.view.showError(error)
                }
            } else {
                let danmakus = collection?.collection ?? []
                DispatchQueue.main.async {
                    hud.label.text = "即将开始播放"
                    hud.progress = 1
                    hud.hide(animated: true, afterDelay: 0.5)
                    self.startPlay(matchsViewController.file, episodeId: episodeId, danmakus: DanmakuManager.shared.conver(danmakus))
                }
            }
        }
    }
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController) {
        matchsViewController.navigationController?.popToRootViewController(animated: true)
        self.startPlay(matchsViewController.file, episodeId: 0, danmakus: [:])
    }
}

extension PlayerViewController: PlayerUIViewDelegate, PlayerUIViewDataSource {
    //MARK: - PlayerUIViewDelegate
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
        self.danmakuCanvas.isHidden = !isOn
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
                  let _ = self.findPlayItem(item)?.episodeId else {
                
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
        self.playOrPauseStateChange()
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
        self.playOrPauseStateChange()
    }
    
    func longPress(playerUIView: PlayerUIView, isBegin: Bool) {
        self.speedUpHUD?.hide(animated: false)
        
        if isBegin {
            //记录原来的速度
            if self.originSpeed == nil {
                self.originSpeed = self.player.speed
            }
            
            self.changeSpeed(4)
            
            let view = MBProgressHUD.showAdded(to: self.view, animated: true)
            self.speedUpHUD = view
            view.offset.y = -1000
            view.mode = .customView
            view.bezelView.color = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
            view.bezelView.style = .solidColor
            view.label.font = .ddp_normal
            view.label.numberOfLines = 0
            view.contentColor = .white
            view.isUserInteractionEnabled = true
            
            let speedUpView = SpeedUpView()
            speedUpView.titleLabel.text = NSLocalizedString("倍速播放中", comment: "")
            speedUpView.startAnimate()
            view.customView = speedUpView
            
        } else {
            //结束恢复默认速度
            if let originSpeed = self.originSpeed {
                self.changeSpeed(originSpeed)
                self.originSpeed = nil
            }
        }
    }
    
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat) {
        self.setPlayerProgress(progress)
    }
    
    func changeProgress(playerUIView: PlayerUIView, diffValue: CGFloat) {
        self.setPlayerProgress(diffValue: diffValue)
    }
    
    func changeBrightness(playerUIView: PlayerUIView, diffValue: CGFloat) {
        
    }
    
    func changeVolume(playerUIView: PlayerUIView, diffValue: CGFloat) {
        self.player.volume += Int(diffValue)
    }
    
    //MARK: - PlayerUIViewDataSource
    func playerMediaThumbnailer(playerUIView: PlayerUIView) -> MediaThumbnailer? {
        return nil
    }
    
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
        
        let pauseIcon = DynamicButton(style: .pause)
        pauseIcon.lineWidth = 6
        pauseIcon.strokeColor = .white
        pauseIcon.highlightStokeColor = .lightGray
        pauseIcon.frame = .init(x: 0, y: 0, width: 50, height: 50)
        view.customView = pauseIcon
        view.hide(animated: true, afterDelay: 0.8)
    }
}

extension PlayerViewController: MediaPlayerDelegate {
    //MARK: - MediaPlayerDelegate
    
    func player(_ player: MediaPlayer, stateDidChange state: PlayerState) {
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
        self.sendDanmakus(at: currentTime)
        self.autoJumpEnding()
    }
    
    func player(_ player: MediaPlayer, file: File, bufferInfoDidChange bufferInfo: MediaBufferInfo) {
        uiView.updateBufferInfos(file.bufferInfos)
    }
    
    /// 遍历当前的弹幕
    /// - Parameter callBack: 回调
    private func forEachDanmakus(_ callBack: (BaseDanmaku) -> Void) {
        for con in danmakuRender.containers {
            if let danmaku = con.danmaku as? BaseDanmaku {
                callBack(danmaku)
            }
        }
    }
}

extension PlayerViewController: DanmakuSettingViewControllerDelegate {
    // MARK: - DanmakuSettingViewControllerDelegate
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuDensity density: Float) {
        
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuAlpha alpha: Float) {
        danmakuCanvas.alpha = CGFloat(alpha)
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuSpeed speed: Float) {
        self.forEachDanmakus { danmaku in
            if let scrollDanmaku = danmaku as? ScrollDanmaku {
                scrollDanmaku.extraSpeed = CGFloat(speed)
            }
        }
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuFontSize fontSize: Double) {
        self.danmakuFont = UIFont.systemFont(ofSize: fontSize)
        self.forEachDanmakus { danmaku in
            danmaku.font = self.danmakuFont
        }
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, danmakuProportion: Double) {
        UIView.animate(withDuration: 0.2) {
            let mainColor = UIColor.mainColor
            let backgroundColor = UIColor(red: mainColor.red, green: mainColor.green, blue: mainColor.blue, alpha: 0.3)
            self.danmakuRender.canvas.backgroundColor = backgroundColor
            
        } completion: { (_) in
            UIView.animate(withDuration: 0.1) {
                self.danmakuRender.canvas.backgroundColor = .clear
            }
        }
        
        self.layoutDanmakuCanvas()
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeShowDanmaku isShow: Bool) {
        self.danmakuCanvas.isHidden = !isShow
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuOffsetTime danmakuOffsetTime: Int) {
        self.danmakuRender.offsetTime = TimeInterval(danmakuOffsetTime)
    }
    
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        self.showFilesVCWithType(.danmaku)
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeMergeSameDanmakuState isOn: Bool) {
        
    }
    
    func searchDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        if let item = self.player.currentPlayItem ?? self.player.playList.first {
            let vc = MatchsViewController(file: item)
            vc.showPlayNowItem = false
            vc.delegate = self
            let nav = NavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .custom
            nav.transitioningDelegate = self.animater
            self.present(nav, animated: true, completion: nil)
        }
        
    }
}

extension PlayerViewController: MediaSettingViewControllerDelegate {
    // MARK: - MediaSettingViewControllerDelegate
    func mediaSettingViewController(_ vc: MediaSettingViewController, didOpenSubtitle subtitle: SubtitleProtocol) {
        self.player.currentSubtitle = subtitle
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangeSubtitleSafeArea isOn: Bool) {
        
        UIView.animate(withDuration: 0.2) {
            let mainColor = UIColor.mainColor
            let backgroundColor = UIColor(red: mainColor.red, green: mainColor.green, blue: mainColor.blue, alpha: 0.3)
            self.danmakuCanvas.backgroundColor = backgroundColor
            
        } completion: { (_) in
            UIView.animate(withDuration: 0.1) {
                self.danmakuCanvas.backgroundColor = .clear
            }
        }

        self.layoutDanmakuCanvas()
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangePlayerSpeed speed: Double) {
        self.changeSpeed(speed)
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangePlayerMode mode: Preferences.PlayerMode) {
        self.changeRepeatMode()
    }
    
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController) {
        self.showFilesVCWithType(.subtitle)
    }
    
}

extension PlayerViewController: FileBrowserViewControllerDelegate {
    // MARK: - FileBrowserViewControllerDelegate
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        
        if didSelectFile.url.isMediaFile {
            self.loadItems(allFiles)
            self.tryParseMedia(didSelectFile)
            vc.dismiss(animated: true, completion: nil)
        } else if didSelectFile.url.isDanmakuFile {
            
            DanmakuManager.shared.downCustomDanmaku(didSelectFile) { [weak self] result1 in
                
                guard let self = self else { return }
                
                switch result1 {
                case .success(let url):
                    do {
                        let converResult = try DanmakuManager.shared.conver(url)
                        DispatchQueue.main.async {
                            self.danmakuDic = converResult
                            vc.dismiss(animated: true, completion: nil)
                            self.view.showHUD(NSLocalizedString("加载本地弹幕成功！", comment: ""))
                        }
                    } catch let error {
                        DispatchQueue.main.async {
                            vc.dismiss(animated: true, completion: nil)
                            self.view.showError(error)
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        vc.dismiss(animated: true, completion: nil)
                        self.view.showError(error)
                    }
                }
            }
        } else if didSelectFile.url.isSubtitleFile {
            SubtitleManager.shared.downCustomSubtitle(didSelectFile) { result1 in
                switch result1 {
                case .success(let subtitle):
                DispatchQueue.main.async {
                    self.player.currentSubtitle = subtitle
                    vc.dismiss(animated: true, completion: nil)
                    self.view.showHUD(NSLocalizedString("加载字幕成功！", comment: ""))
                }
                case .failure(let error):
                    DispatchQueue.main.async {
                        vc.dismiss(animated: true, completion: nil)
                        self.view.showError(error)
                    }
                }
            }
        }
    }
}
