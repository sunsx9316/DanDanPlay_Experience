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
import RxSwift


class PlayerViewController: ViewController {
    
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
    
    /// 弹幕画布容器
    private lazy var danmakuCanvas: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var animater = PlayerControlAnimater()
    
    private lazy var model = PlayerModel()
    
    private lazy var disposeBag = DisposeBag()
    
    private var parseMediaHUD: MBProgressHUD?
    
    ///加速指示器
    private weak var speedUpHUD: MBProgressHUD?
    
    ///开启临时加速前的速度
    private var originSpeed: Double?
    
    private var firstPlayMediaCallBack: (() -> File?)?
    
    private weak var gotoLastWatchPointView: GotoLastWatchPointView?
    
    //MARK: - life cycle
    
    init(items: [File], selectedItem: File? = nil) {
        super.init(nibName: nil, bundle: nil)
        
        Helper.shared.playerViewController = self
        
        self.model.loadMedias(items)
        
        self.firstPlayMediaCallBack = {

            if let selectedItem = selectedItem {
                return selectedItem
            }
            
            return items.first
        }
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

        if (try? self.model.isPlay.value()) == true {
            self.model.pause()
        }
        
        self.model.storeProgress()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.model.mediaView)
        self.containerView.addSubview(self.danmakuCanvas)
        self.view.addSubview(self.uiView)
        self.danmakuCanvas.addSubview(self.model.danmakuView)
        
        self.containerView.snp.makeConstraints { (make) in
            make.top.leading.trailing.bottom.equalTo(self.view)
        }
        
        self.model.mediaView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.containerView)
        }
        
        self.uiView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.bindModel()
        self.initPreferences()
        self.uiView.autoShowControlView()
        
        if let firstPlayMedia = self.firstPlayMediaCallBack?() {
            self.model.tryParseMedia(firstPlayMedia)
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
    
    
    //MARK: Private
    
    private func bindModel() {
        self.model.media.subscribe(onNext: { [weak self] file in
            guard let self = self else { return }
            
            self.uiView.title = file?.fileName
        }).disposed(by: self.disposeBag)
        
        self.model.time.subscribe(onNext: { [weak self] timeInfo in
            guard let self = self else { return }

            self.uiView.updateTime()
        }).disposed(by: self.disposeBag)
        
        self.model.isPlay.subscribe(onNext: { [weak self] isPlay in
            guard let self = self else { return }
            
            self.uiView.isPlay = isPlay
        }).disposed(by: self.disposeBag)
        
        self.model.buffer.subscribe(onNext: { [weak self] bufferInfos in
            guard let self = self else { return }
            
            self.uiView.updateBufferInfos(bufferInfos ?? [])
        }).disposed(by: self.disposeBag)

        self.model.parseMediaState.subscribe(onNext: { [weak self] event in
            guard let self = self else { return }
            
            self.parseMedia(event: event)
        }).disposed(by: self.disposeBag)
    }
    
    /// 弹出文件选择器
    /// - Parameter type: 筛选文件类型
    private func showFilesVCWithType(_ type: URLFilterType) {
        
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        let item = (try? self.model.media.value()) ?? self.model.playList.first
        
        if let parentFile = item?.parentFile {
            let vc = FileBrowserViewController(with: parentFile, selectedFile: item, filterType: type)
            vc.delegate = self
            let nav = NavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .custom
            nav.transitioningDelegate = self.animater
            self.present(nav, animated: true, completion: nil)
        }
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
        
        self.model.danmakuView.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            let danmakuProportion = Preferences.shared.danmakuProportion
            make.height.equalToSuperview().multipliedBy(danmakuProportion)
        }
    }
    
    /// 应用偏好设置
    private func initPreferences() {
        self.danmakuCanvas.alpha = CGFloat(Preferences.shared.danmakuAlpha)
        self.danmakuCanvas.isHidden = !Preferences.shared.isShowDanmaku
        self.layoutDanmakuCanvas()
        
        self.model.initPreferences()
    }
    
    /// 显示播放器装填
    /// - Parameter isPlay: 是否正在播放
    private func showPlayStateHUD(isPlay: Bool) {
        let view = MBProgressHUD.showAdded(to: self.view, animated: true)
        view.mode = .customView
        view.bezelView.color = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        view.bezelView.style = .solidColor
        view.label.font = .ddp_normal
        view.label.numberOfLines = 0
        view.contentColor = .white
        view.isUserInteractionEnabled = true
        
        let pauseIcon = DynamicButton(style: isPlay ? .play : .pause)
        pauseIcon.lineWidth = 6
        pauseIcon.strokeColor = .white
        pauseIcon.highlightStokeColor = .lightGray
        pauseIcon.frame = .init(x: 0, y: 0, width: 50, height: 50)
        view.customView = pauseIcon
        view.hide(animated: true, afterDelay: 0.8)
    }
}

//MARK: - PlayerUIViewDelegate
extension PlayerViewController: PlayerUIViewDelegate {
    func playerUIViewDidRestScale(_ playerUIView: PlayerUIView) {
        self.model.mediaView.transform = .identity
    }
    
    func playerUIView(_ playerUIView: PlayerUIView, didChangeScale scale: Double) {
        self.model.mediaView.transform = self.model.mediaView.transform.scaledBy(x: scale, y: scale)
    }
    
    func onTouchMoreButton(playerUIView: PlayerUIView) {
        let vc = PlayerSettingViewController(playerModel: self.model)
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
        guard let item = try? self.model.media.value(), !self.model.isMatch(media: item) else {
            self.view.showHUD("需要指定视频弹幕列表，才能发弹幕哟~")
            return
        }
        
        let vc = SendDanmakuViewController()
        vc.onTouchSendButtonCallBack = { [weak self] (text, aVC) in
            guard let self = self else { return }
            
            guard let item = try? self.model.media.value(), !self.model.isMatch(media: item) else {
                self.view.showHUD("需要指定视频弹幕列表，才能发弹幕哟~")
                return
            }
            
            aVC.navigationController?.popViewController(animated: true)
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func onTouchPlayButton(playerUIView: PlayerUIView, isSelected: Bool) {
        if self.model.changePlayState() == .pause {
            self.showPlayStateHUD(isPlay: false)
        } else {
            self.showPlayStateHUD(isPlay: true)
        }
    }
    
    func doubleTap(playerUIView: PlayerUIView) {
        if self.model.changePlayState() == .pause {
            self.showPlayStateHUD(isPlay: false)
        } else {
            self.showPlayStateHUD(isPlay: true)
        }
    }
    
    func onTouchNextButton(playerUIView: PlayerUIView) {
        if let media = self.model.nextMedia() {
            self.model.tryParseMedia(media)
        }
    }
    
    func longPress(playerUIView: PlayerUIView, isBegin: Bool) {
        self.speedUpHUD?.hide(animated: false)
        
        if isBegin {
            //记录原来的速度
            if self.originSpeed == nil {
                self.originSpeed = self.model.speed
            }
            
            self.model.changeSpeed(4)
            
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
                self.model.changeSpeed(originSpeed)
                self.originSpeed = nil
            }
        }
    }
    
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat) {
        self.model.setPlayerProgress(progress)
    }
    
    func changeProgress(playerUIView: PlayerUIView, diffValue: CGFloat) {
        self.model.setPlayerProgress(diffValue: diffValue)
    }
    
    func changeBrightness(playerUIView: PlayerUIView, diffValue: CGFloat) {
        
    }
    
    func playerUIView(_ playerUIView: PlayerUIView, didChangeControlViewState show: Bool) {
        self.setNeedsStatusBarAppearanceUpdate()
    }
}

//MARK: - PlayerUIViewDataSource
extension PlayerViewController: PlayerUIViewDataSource {
    func playerMediaThumbnailer(playerUIView: PlayerUIView) -> MediaThumbnailer? {
        return nil
    }
    
    func playerCurrentTime(playerUIView: PlayerUIView) -> TimeInterval {
        return self.model.currentTime
    }
    
    func playerTotalTime(playerUIView: PlayerUIView) -> TimeInterval {
        return self.model.length
    }
    
    func playerProgress(playerUIView: PlayerUIView) -> CGFloat {
        return CGFloat(self.model.position)
    }
    
    func shouldShowResetScaleButton(playerUIView: PlayerUIView) -> Bool {
        return self.model.mediaView.transform != .identity
    }
}

// MARK: - DanmakuSettingViewControllerDelegate
extension PlayerViewController: DanmakuSettingViewControllerDelegate {
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuDensity density: Float) {
        
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuAlpha alpha: Float) {
        danmakuCanvas.alpha = CGFloat(alpha)
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuSpeed speed: Float) {
        self.model.changeDanmakuSpeed(speed)
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuFontSize fontSize: Double) {
        self.model.changeDanmakuFontSize(fontSize: fontSize)
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, danmakuProportion: Double) {
        UIView.animate(withDuration: 0.2) {
            let mainColor = UIColor.mainColor
            let backgroundColor = UIColor(red: mainColor.red, green: mainColor.green, blue: mainColor.blue, alpha: 0.3)
            self.model.danmakuView.backgroundColor = backgroundColor
            
        } completion: { (_) in
            UIView.animate(withDuration: 0.1) {
                self.model.danmakuView.backgroundColor = .clear
            }
        }
        
        self.layoutDanmakuCanvas()
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeShowDanmaku isShow: Bool) {
        self.danmakuCanvas.isHidden = !isShow
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuOffsetTime danmakuOffsetTime: Int) {
        self.model.setDanmakuOffsetTime(TimeInterval(danmakuOffsetTime))
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
        
        if let item = (try? self.model.media.value()) ?? self.model.playList.first {
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

// MARK: - MediaSettingViewControllerDelegate
extension PlayerViewController: MediaSettingViewControllerDelegate {
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangeSubtitleFontSize subtitleFontSize: Float) {
        self.model.changeSubtitleFontSize(fontSize: subtitleFontSize)
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangeSubtitleMargin subtitleMargin: Int) {
        self.model.changeSubtitleMargin(subtitleMargin: subtitleMargin)
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangeSubtitleOffsetTime subtitleOffsetTime: Int) {
        self.model.changeSubtltleDelay(subtitleDelay: subtitleOffsetTime)
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didOpenSubtitle subtitle: SubtitleProtocol) {
        self.model.currentSubtitle = subtitle
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
        self.model.changeSpeed(speed)
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangePlayerMode mode: Preferences.PlayerMode) {
        self.model.changeRepeatMode(playerMode: mode)
    }
    
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController) {
        self.showFilesVCWithType(.subtitle)
    }
    
}

// MARK: - FileBrowserViewControllerDelegate
extension PlayerViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        
        if didSelectFile.url.isMediaFile {
            self.model.loadMedias(allFiles)
            self.model.tryParseMedia(didSelectFile)
            vc.dismiss(animated: true, completion: nil)
        } else if didSelectFile.url.isDanmakuFile {
            _ = self.model.loadDanmakuByUser(didSelectFile).subscribe(onError: { [weak self, weak vc] error in
                guard let self = self else { return }
                
                vc?.dismiss(animated: true, completion: nil)
                self.view.showError(error)
            }, onCompleted: { [weak self, weak vc] in
                guard let self = self else { return }
                
                vc?.dismiss(animated: true, completion: nil)
                self.view.showHUD(NSLocalizedString("加载本地弹幕成功！", comment: ""))
            })
        } else if didSelectFile.url.isSubtitleFile {
            _ = self.model.loadSubtitleByUser(didSelectFile).subscribe(onError: { [weak self, weak vc] error in
                guard let self = self else { return }
                
                vc?.dismiss(animated: true, completion: nil)
                self.view.showError(error)
            }, onCompleted: { [weak self, weak vc] in
                guard let self = self else { return }
                
                vc?.dismiss(animated: true, completion: nil)
                self.view.showHUD(NSLocalizedString("加载字幕成功！", comment: ""))
            })
        }
    }
}


// MARK: - MatchsViewControllerDelegate
extension PlayerViewController: MatchsViewControllerDelegate {
    
    func matchsViewController(_ matchsViewController: MatchsViewController, didSelectedEpisodeId episodeId: Int) {
        
        switch matchsViewController.style {
        case .full:
            matchsViewController.navigationController?.popToRootViewController(animated: true)
        case .mini:
            if let presentedViewController = self.presentedViewController {
                presentedViewController.dismiss(animated: true, completion: nil)
            }
        }
        
        _ = self.model.didMatchMedia(matchsViewController.file, episodeId: episodeId).subscribe { [weak self] event in
            guard let self = self else { return }
            
            self.parseMedia(event: event)
        }
    }
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController) {
        matchsViewController.navigationController?.popToRootViewController(animated: true)
        _ = self.model.startPlay(matchsViewController.file, episodeId: 0, danmakus: [:])
    }
    
    
    /// 解析视频
    /// - Parameters:
    ///   - event: 解析事件
    ///   - hud: 指示器
    private func parseMedia(event: RxSwift.Event<PlayerModel.MediaLoadState>) {
        
        if self.parseMediaHUD == nil {
            self.parseMediaHUD = self.view.showProgress()
        }
        
        switch event {
        case .next(let element):
            switch element {
            case .parse(let state, let progress):
                
                self.parseMediaHUD?.progress = 0.8 * progress
                
                
                switch state {
                case .parseMedia:
                    self.parseMediaHUD?.label.text = NSLocalizedString("开始解析...", comment: "")
                case .downloadLocalDanmaku:
                    self.parseMediaHUD?.label.text = NSLocalizedString("下载本地弹幕...", comment: "")
                case .matchMedia(progress: _):
                    self.parseMediaHUD?.label.text = NSLocalizedString("解析视频中...", comment: "")
                case .downloadDanmaku:
                    self.parseMediaHUD?.label.text = NSLocalizedString("加载弹幕中...", comment: "")
                }
                
            case .subtitle(_):
                self.parseMediaHUD?.progress = 0.85
                self.parseMediaHUD?.label.text = NSLocalizedString("加载字幕中...", comment: "")
            case .lastWatchProgress(let lastWatchProgress):
                self.parseMediaHUD?.progress = 1
                self.parseMediaHUD?.label.text = NSLocalizedString("即将开始播放...", comment: "")
                
                self.showGotoLastWatchTime(lastWatchProgress: lastWatchProgress, retryTime: 0)
            }
        case .error(let error):
            if let error = error as? PlayerModel.ParseError {
                switch error {
                case .notMatched(let collection, let media):
                    let vc = MatchsViewController(with: collection, file: media)
                    vc.delegate = self
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            } else {
                self.view.showError(error)
            }
            
            self.parseMediaHUD?.hide(animated: true, afterDelay: 0.3)
            self.parseMediaHUD = nil
        case .completed:
            self.parseMediaHUD?.hide(animated: true, afterDelay: 0.3)
            self.parseMediaHUD = nil
        }
    }
    
    
    /// 显示上次播放进度
    /// - Parameters:
    ///   - lastWatchProgress: 上次播放进度
    ///   - retryTime: 重试次数
    private func showGotoLastWatchTime(lastWatchProgress: TimeInterval, retryTime: Int) {
        let totalTime = self.model.length
        
        if totalTime == 0 && retryTime < 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showGotoLastWatchTime(lastWatchProgress: lastWatchProgress, retryTime: retryTime + 1)
            }
        } else if totalTime > 0 {
            func lastTimeString() -> String {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "mm:ss"
                return timeFormatter.string(from: Date(timeIntervalSince1970: totalTime * lastWatchProgress))
            }
            
            self.gotoLastWatchPointView?.dismiss()
            
            let customView = GotoLastWatchPointView()
            customView.timeString = NSLocalizedString("上次观看时间：", comment: "") + lastTimeString()
            customView.didClickGotoButton = { [weak self] in
                guard let self = self else { return }
                
                self.model.setPlayerProgress(lastWatchProgress)
                self.uiView.autoShowControlView()
            }
            
            customView.show(from: self.view)
            self.gotoLastWatchPointView = customView
        } else {
            if let url = try? self.model.media.value()?.url {
                ANX.logError(.UI, "视频时长获取失败 \(url)")
            }
        }
    }
}
