//
//  PlayerViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/26.
//

import UIKit
import SnapKit
import YYCategories
import MBProgressHUD
import RxSwift
import ANXLog
import AVFoundation
import AVKit

class PlayerViewController: ViewController {
    
    private lazy var uiView: PlayerUIView = {
        let view = PlayerUIView()
        view.delegate = self
        view.dataSource = self
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    /// 弹幕画布容器
    private lazy var danmakuCanvas: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var animater = PlayerControlAnimater()
    
    private lazy var playerModel = PlayerModel()
    
    private var danmakuModel: PlayerDanmakuModel {
        return self.playerModel.danmakuModel
    }
    
    private var mediaModel: PlayerMediaModel {
        return self.playerModel.mediaModel
    }
    
    
    private lazy var disposeBag = DisposeBag()
    
    private var parseMediaHUD: MBProgressHUD?
    
    ///加速指示器
    private weak var speedUpHUD: MBProgressHUD?
    
    ///开启临时加速前的速度
    private var originSpeed: Double?
    
    private var firstPlayMediaCallBack: (() -> File?)?
    
    private weak var gotoLastWatchPointView: GotoLastWatchPointView?

    // MARK: - PiP

    private var pipController: AVPictureInPictureController?
    private var pipOverlayView: PiPOverlayView?

    //MARK: - life cycle
    
    init(items: [File], selectedItem: File? = nil) {
        super.init(nibName: nil, bundle: nil)
        
        Helper.shared.playerViewController = self
        
        self.mediaModel.loadMedias(items)
        
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

        if self.mediaModel.isPlaying {
            self.playerModel.mediaModel.pause()
        }
    }
    
    deinit {
        self.playerModel.mediaModel.terminate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.mediaModel.mediaView)
        self.containerView.addSubview(self.danmakuCanvas)
        self.view.addSubview(self.uiView)
        self.danmakuCanvas.addSubview(self.danmakuModel.danmakuView)

        // PiP 初始化
        setupPiP()

        self.containerView.snp.makeConstraints { (make) in
            make.top.leading.trailing.bottom.equalTo(self.view)
        }
        
        self.mediaModel.mediaView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.containerView)
        }
        
        self.uiView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.bindModel()
        self.uiView.autoShowControlView()
        
        if let firstPlayMedia = self.firstPlayMediaCallBack?() {
            self.playerModel.tryParseMedia(firstPlayMedia)
        }
    }

    // MARK: - PiP Setup

    private func setupPiP() {
        mediaModel.onPiPToggleChanged = { [weak self] enabled in
            guard let self = self else { return }
            if enabled {
                self.startPiP()
            } else {
                self.stopPiP()
            }
        }
    }

    // MARK: - PiP Actions

    private func startPiP() {
        guard #available(iOS 15.0, *) else {
            ANX.logError(.player, "[PiP] PiP 需要 iOS 15.0+")
            return
        }
        guard pipController == nil else { return }
        guard let file = mediaModel.media,
              file.createMPVMedia() != nil else {
            ANX.logError(.player, "[PiP] 无法获取当前播放文件")
            return
        }

        // 先创建 PiP player（extract 会快照当前播放状态）
        guard let pipPlayer = mediaModel.createPiPPlayer() else { return }

        // 再暂停主播放器
        ANX.logInfo(.player, "[PiP] 暂停主播放器")
        mediaModel.pause()

        let manager = mediaModel.createPiPManager(with: pipPlayer, media: file)

        // 回调
        manager.onReadyForPiPStart = { [weak self] in
            self?.pipController?.startPictureInPicture()
        }
        manager.onStateChanged = { [weak self] state in
            ANX.logInfo(.player, "[PiP] 状态变更: \(state)")
            if state == .inactive {
                self?.handlePiPStopped()
            }
        }
        manager.onEndOfFile = { [weak self] in
            guard let self = self else { return false }
            guard let manager = self.mediaModel.pipManager,
                  let nextMedia = self.mediaModel.nextMediaForPlayMode(from: manager.currentMedia) else {
                ANX.logInfo(.player, "[PiP] 无下一集，PiP 退出")
                return false
            }
            ANX.logInfo(.player, "[PiP] 自动播放下一集: \(nextMedia.fileName)")
            guard nextMedia.createMPVMedia() != nil,
                  let pipPlayer = self.mediaModel.createPiPPlayer() else {
                ANX.logError(.player, "[PiP] 创建下一集 PiP 播放器失败")
                return false
            }
            manager.restart(with: pipPlayer, media: nextMedia)
            return true
        }
        manager.onRestoreUI = {
            // PiP 窗口点"返回"
        }

        // AVPictureInPictureController
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: manager.displayLayer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        self.pipController = controller

        // Sample buffer 视图
        view.insertSubview(manager.sampleBufferView, aboveSubview: containerView)
        manager.sampleBufferView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        manager.sampleBufferView.alpha = 0.01

        // AudioSession
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            ANX.logError(.player, "[PiP] AudioSession error: \(error)")
        }
    }

    private func stopPiP() {
        ANX.logInfo(.player, "[PiP] 用户关闭画中画")
        let wasPlaying = mediaModel.pipManager?.isPlaying ?? false
        let finalPosition = mediaModel.pipManager?.currentPosition ?? 0
        let pipMedia = mediaModel.pipManager?.currentMedia
        mediaModel.pipManager?.sampleBufferView.removeFromSuperview()
        mediaModel.stopPiP()
        pipController?.stopPictureInPicture()
        pipController = nil
        syncMainPlayerToPiP(pipMedia: pipMedia, position: finalPosition, autoPlay: wasPlaying)
    }

    private func handlePiPStopped() {
        let wasPlaying = mediaModel.pipManager?.isPlaying ?? false
        let finalPosition = mediaModel.pipManager?.currentPosition ?? 0
        let pipMedia = mediaModel.pipManager?.currentMedia
        mediaModel.pipManager?.sampleBufferView.removeFromSuperview()
        mediaModel.stopPiP()
        pipController = nil
        hidePiPOverlay()
        syncMainPlayerToPiP(pipMedia: pipMedia, position: finalPosition, autoPlay: wasPlaying)
    }

    /// PiP 退出时同步状态到主播放器：如果已自动切集，则切换主播放器到新集
    private func syncMainPlayerToPiP(pipMedia: File?, position: Double, autoPlay: Bool) {
        if let pipMedia = pipMedia, pipMedia.fileId != mediaModel.media?.fileId {
            ANX.logInfo(.player, "[PiP] 同步主播放器到新集: \(pipMedia.fileName)")
            mediaModel.switchToMedia(pipMedia, autoPlay: autoPlay)
        } else {
            mediaModel.syncPlayerPosition(position, autoPlay: autoPlay)
        }
    }

    // MARK: - PiP Overlay

    private func showPiPOverlay() {
        guard pipOverlayView == nil else { return }
        let overlay = PiPOverlayView()
        overlay.onTap = { [weak self] in
            self?.stopPiP()
        }
        view.addSubview(overlay)
        overlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        pipOverlayView = overlay
    }

    private func hidePiPOverlay() {
        pipOverlayView?.removeFromSuperview()
        pipOverlayView = nil
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

        self.playerModel.parseMediaState.subscribe(onNext: { [weak self] event in
            guard let self = self else { return }
            
            self.parseMedia(event: event)
        }).disposed(by: self.disposeBag)
        
        self.bindMediaModel()
        self.bindDanmakuModel()
    }
    
    private func bindMediaModel() {
        self.mediaModel.context.media.subscribe(onNext: { [weak self] file in
            guard let self = self else { return }
            
            self.uiView.title = file?.fileName
        }).disposed(by: self.disposeBag)
        
        self.mediaModel.context.time.subscribe(onNext: { [weak self] timeInfo in
            guard let self = self else { return }

            self.uiView.updateTime()
        }).disposed(by: self.disposeBag)
        
        self.mediaModel.context.isPlay.subscribe(onNext: { [weak self] isPlay in
            guard let self = self else { return }

            self.uiView.isPlay = isPlay
            UIApplication.shared.isIdleTimerDisabled = isPlay

        }).disposed(by: self.disposeBag)
        
        self.mediaModel.context.buffer.subscribe(onNext: { [weak self] bufferInfos in
            guard let self = self else { return }
            
            self.uiView.updateBufferInfos(bufferInfos ?? [])
        }).disposed(by: self.disposeBag)
        
        self.mediaModel.context.subtitleSafeArea.subscribe(onNext: { [weak self] subtitleSafeArea in
            guard let self = self else { return }
            
            self.danmakuCanvas.snp.remakeConstraints { (make) in
                make.top.leading.trailing.equalTo(self.containerView)
                if subtitleSafeArea {
                    make.height.equalTo(self.containerView).multipliedBy(0.85)
                } else {
                    make.height.equalTo(self.containerView)
                }
            }
            
        }).disposed(by: self.disposeBag)
        
        /// 高亮调整区域，初始化时不展示颜色
        self.mediaModel.context.subtitleSafeArea.skip(1).subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }

            UIView.animate(withDuration: 0.2) {
                let mainColor = UIColor.mainColor
                let backgroundColor = UIColor(red: mainColor.red, green: mainColor.green, blue: mainColor.blue, alpha: 0.7)
                self.danmakuCanvas.backgroundColor = backgroundColor
                
            } completion: { (_) in
                UIView.animate(withDuration: 0.1) {
                    self.danmakuCanvas.backgroundColor = .clear
                }
            }
            
        }).disposed(by: self.disposeBag)
        
    }
    
    
    private func bindDanmakuModel() {
        self.danmakuModel.context.danmakuAlpha.subscribe(onNext: { [weak self] danmakuAlpha in
            guard let self = self else { return }
            
            self.danmakuCanvas.alpha = CGFloat(danmakuAlpha)
        }).disposed(by: self.disposeBag)
        
        self.danmakuModel.context.isShowDanmaku.subscribe(onNext: { [weak self] isShowDanmaku in
            guard let self = self else { return }
            
            self.danmakuCanvas.isHidden = !isShowDanmaku
        }).disposed(by: self.disposeBag)
        
        self.danmakuModel.context.danmakuArea.subscribe(onNext: { [weak self] danmakuArea in
            guard let self = self else { return }
                    
            self.danmakuModel.danmakuView.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.height.equalToSuperview().multipliedBy(danmakuArea.value)
            }
            
        }).disposed(by: self.disposeBag)
        
        /// 高亮调整区域，初始化时不展示颜色
        self.danmakuModel.context.danmakuArea.skip(1).subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
   
            
            UIView.animate(withDuration: 0.2) {
                let mainColor = UIColor.mainColor
                let backgroundColor = UIColor(red: mainColor.red, green: mainColor.green, blue: mainColor.blue, alpha: 0.7)
                self.danmakuModel.danmakuView.backgroundColor = backgroundColor
                
            } completion: { (_) in
                UIView.animate(withDuration: 0.1) {
                    self.danmakuModel.danmakuView.backgroundColor = .clear
                }
            }
            
        }).disposed(by: self.disposeBag)
        
    }
    
    /// 弹出文件选择器
    /// - Parameter type: 筛选文件类型
    private func showFilesVCWithType(_ type: URLFilterType) {
        
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        let item = self.mediaModel.media ?? self.mediaModel.playList.first
        
        if let parentFile = item?.parentFile {
            let vc = FileBrowserViewController(with: parentFile, selectedFile: item, filterType: type)
            vc.delegate = self
            let nav = NavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .custom
            nav.transitioningDelegate = self.animater
            self.present(nav, animated: true, completion: nil)
        }
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
        
        let pauseIcon = PlayPauseButton()
        pauseIcon.iconStyle = isPlay ? .play : .pause
        pauseIcon.iconLineWidth = 6
        pauseIcon.iconStrokeColor = .white
        pauseIcon.iconHighlightStrokeColor = .lightGray
        pauseIcon.frame = .init(x: 0, y: 0, width: 50, height: 50)
        view.customView = pauseIcon
        view.hide(animated: true, afterDelay: 0.8)
    }
    
}

extension PlayerViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIDevice.current.isPad ? .popover : .none
    }
}

//MARK: - PlayerUIViewDelegate
extension PlayerViewController: PlayerUIViewDelegate {
    func singleTap(playerUIView: PlayerUIView, point: CGPoint, showUIViewCallBack: @escaping (() -> Void)) {


        let pointInDanmakuCanvas = self.danmakuModel.danmakuView.convert(point, from: playerUIView)
        if let danmakuCanvas = self.danmakuModel.selectedDanmaku(at: pointInDanmakuCanvas) {
            /// 命中弹幕，弹出气泡
            ANX.logInfo(.player, "[Player] 点击弹幕")
            let vc = DanmakuOperationViewViewController()
            vc.onTouchCopyButtonCallBack = { [weak self] avc in
                avc.dismiss(animated: true)
                self?.danmakuModel.copyDanmkuText(danmakuCanvas)
                ANX.logInfo(.player, "[Player] 复制弹幕文本")
            }

            vc.onTouchFilterButtonCallBack = { [weak self] avc in
                avc.dismiss(animated: true)
                self?.danmakuModel.onAddFilterDanmku(danmakuCanvas)
                ANX.logInfo(.player, "[Player] 屏蔽该弹幕")
            }

            vc.dismissCallBack = { [weak self] avc in
                self?.danmakuModel.deselectDanmaku()
            }

            vc.modalPresentationStyle = .popover
            vc.popoverPresentationController?.sourceView = self.danmakuModel.danmakuView
            vc.popoverPresentationController?.sourceRect = CGRect(x: danmakuCanvas.frame.midX, y: danmakuCanvas.frame.maxY, width: 0, height: 0);
            vc.popoverPresentationController?.permittedArrowDirections = .up;
            vc.preferredContentSize = CGSize.init(width: 120, height: 50);

            if let pres = vc.presentationController {
                pres.delegate = self
            }

            self.present(vc, animated: true, completion: nil)
        } else {
            showUIViewCallBack()
            self.danmakuModel.deselectDanmaku()
        }
    }
    
    func playerUIViewDidRestScale(_ playerUIView: PlayerUIView) {
        self.mediaModel.mediaView.transform = .identity
    }
    
    func playerUIView(_ playerUIView: PlayerUIView, didChangeScale scale: Double) {
        self.mediaModel.mediaView.transform = self.mediaModel.mediaView.transform.scaledBy(x: scale, y: scale)
    }
    
    func onTouchMoreButton(playerUIView: PlayerUIView) {
        ANX.logInfo(.player, "[Player] 打开播放设置")
        let vc = PlayerSettingViewController(playerModel: self.playerModel)
        vc.delegate = self
        vc.transitioningDelegate = self.animater
        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = animater
        self.present(vc, animated: true, completion: nil)
    }
    
    func onTouchPlayerList(playerUIView: PlayerUIView) {
        ANX.logInfo(.player, "[Player] 打开播放列表")
        self.showFilesVCWithType(.video)
    }
    
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool) {
        ANX.logInfo(.player, "[Player] 弹幕开关: \(isOn ? "开启" : "关闭")")
        self.danmakuCanvas.isHidden = !isOn
    }

    func playerUIView(_ playerUIView: PlayerUIView, didChangeDanmakuInputViewState isExpanding: Bool) {
        if isExpanding {
            ANX.logInfo(.player, "[Player] 展开弹幕输入面板，暂停播放")
            self.mediaModel.pause()
        } else {
            ANX.logInfo(.player, "[Player] 收起弹幕输入面板，继续播放")
            self.mediaModel.changePlayState()
        }
    }

    func playerUIView(_ playerUIView: PlayerUIView, didSendDanmaku text: String, mode: Comment.Mode, color: ANXColor) {
        guard let item = self.mediaModel.media, let matchInfo = self.mediaModel.matchInfo(media: item), matchInfo.matchId > 0 else {
            self.view.showHUD("需要指定视频弹幕列表，才能发弹幕哟~")
            return
        }

        ANX.logInfo(.player, "[Player] 发送弹幕: \(text), mode: \(mode), color: \(color)")

        var comment = Comment()
        comment.time = self.danmakuModel.currentTime
        comment.mode = mode
        comment.color = color
        comment.message = text
        
        self.danmakuModel.sendDanmaku(matchId: matchInfo.matchId, danmaku: comment) { [weak self] isSuccess, msg in
            if let msg = msg {
                self?.view.showHUD(msg)
            }
        }
    }
    
    func onTouchPlayButton(playerUIView: PlayerUIView, isSelected: Bool) {
        changePlayState()
    }
    
    func doubleTap(playerUIView: PlayerUIView) {
        changePlayState()
    }
    
    func onTouchNextButton(playerUIView: PlayerUIView) {
        if let media = self.mediaModel.nextMedia() {
            ANX.logInfo(.player, "[Player] 切换下一集: \(media.fileName)")
            self.playerModel.tryParseMedia(media)
        } else {
            ANX.logInfo(.player, "[Player] 没有下一集")
        }
    }
    
    func longPress(playerUIView: PlayerUIView, isBegin: Bool) {
        self.speedUpHUD?.hide(animated: false)

        if isBegin {
            //记录原来的速度
            if self.originSpeed == nil {
                self.originSpeed = self.mediaModel.playerSpeed
            }
            ANX.logInfo(.player, "[Player] 长按开始倍速播放: 4x (原速度: \(self.originSpeed ?? 1.0))")
            self.playerModel.changeSpeed(4)

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
                ANX.logInfo(.player, "[Player] 长按结束恢复速度: \(originSpeed)")
                self.playerModel.changeSpeed(originSpeed)
                self.originSpeed = nil
            }
        }
    }
    
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat) {
        ANX.logInfo(.player, "[Player] 滑动跳转进度: \(Int(progress * 100))%")
        self.playerModel.changePosition(progress)
    }

    func changeProgress(playerUIView: PlayerUIView, diffValue: CGFloat) {
        ANX.logDebug(.player, "[Player] 进度微调: \(diffValue)s")
        self.playerModel.changePosition(diffValue: diffValue)
    }
    
    func playerUIView(_ playerUIView: PlayerUIView, didChangeControlViewState show: Bool) {
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    func changeBrightness(playerUIView: PlayerUIView, diffValue: CGFloat) {
        
    }
    
    private func changePlayState() {
        let state = self.mediaModel.changePlayState()
        if state == .pause {
            ANX.logInfo(.player, "[Player] 用户暂停播放")
            self.showPlayStateHUD(isPlay: false)
        } else {
            ANX.logInfo(.player, "[Player] 用户开始播放")
            self.showPlayStateHUD(isPlay: true)
        }
    }
    
}

//MARK: - PlayerUIViewDataSource
extension PlayerViewController: PlayerUIViewDataSource {
    func playerMediaThumbnailer(playerUIView: PlayerUIView) -> MediaThumbnailer? {
        return nil
    }
    
    func playerCurrentTime(playerUIView: PlayerUIView) -> TimeInterval {
        return self.mediaModel.currentTime
    }
    
    func playerTotalTime(playerUIView: PlayerUIView) -> TimeInterval {
        return self.mediaModel.length
    }
    
    func playerProgress(playerUIView: PlayerUIView) -> CGFloat {
        return CGFloat(self.mediaModel.position)
    }
    
    func shouldShowResetScaleButton(playerUIView: PlayerUIView) -> Bool {
        return self.mediaModel.mediaView.transform != .identity
    }
}

// MARK: - DanmakuSettingViewControllerDelegate
extension PlayerViewController: DanmakuSettingViewControllerDelegate {
    
    func filterDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        let vc = FilterDanmakuViewController(danmakuModel: self.danmakuModel)
        let nav = NavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .custom
        nav.transitioningDelegate = self.animater
        self.present(nav, animated: true, completion: nil)
    }
    
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        self.showFilesVCWithType(.danmaku)
    }

    func showDanmakuListInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }

        let vc = DanmakuListViewController(danmakuModel: self.danmakuModel)
        let nav = NavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .custom
        nav.transitioningDelegate = self.animater
        self.present(nav, animated: true, completion: nil)
    }

    func searchDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        if let item = self.mediaModel.media ?? self.mediaModel.playList.first {
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
    func changeSubtitleFontInMediaSettingViewController(_ vc: MediaSettingViewController) {
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        let vc = SelectedFontViewController(mediaModel: self.mediaModel)
        let nav = NavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .custom
        nav.transitioningDelegate = self.animater
        self.present(nav, animated: true, completion: nil)
    }
    
        
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController) {
        self.showFilesVCWithType(.subtitle)
    }
    
}

// MARK: - FileBrowserViewControllerDelegate
extension PlayerViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        
        if didSelectFile.url.isMediaFile {
            self.mediaModel.loadMedias(allFiles)
            self.playerModel.tryParseMedia(didSelectFile)
            vc.dismiss(animated: true, completion: nil)
        } else if didSelectFile.url.isDanmakuFile {
            _ = self.danmakuModel.loadDanmakuByUser(didSelectFile).subscribe(onError: { [weak self, weak vc] error in
                guard let self = self else { return }
                
                vc?.dismiss(animated: true, completion: nil)
                self.view.showError(error)
            }, onCompleted: { [weak self, weak vc] in
                guard let self = self else { return }
                
                vc?.dismiss(animated: true, completion: nil)
                self.view.showHUD(NSLocalizedString("加载本地弹幕成功！", comment: ""))
            })
        } else if didSelectFile.url.isSubtitleFile {
            _ = self.mediaModel.loadSubtitleByUser(didSelectFile).subscribe(onError: { [weak self, weak vc] error in
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
    func matchsViewController(_ matchsViewController: MatchsViewController, didMatched matchInfo: any MatchInfo) {
        switch matchsViewController.style {
        case .full:
            matchsViewController.navigationController?.popToRootViewController(animated: true)
        case .mini:
            if let presentedViewController = self.presentedViewController {
                presentedViewController.dismiss(animated: true, completion: nil)
            }
        }
        
        _ = self.playerModel.didMatchMedia(matchsViewController.file, matchInfo: matchInfo).subscribe { [weak self] event in
            guard let self = self else { return }
            
            self.parseMedia(event: event)
        }
    }
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController) {
        matchsViewController.navigationController?.popToRootViewController(animated: true)
        _ = self.playerModel.startPlay(matchsViewController.file, matchInfo: nil, danmakus: [:]).subscribe { [weak self] event in
            guard let self = self else { return }
            
            self.parseMedia(event: event)
        }
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
                
            case .filterDanmaku(progress: _):
                self.parseMediaHUD?.progress = 0.85
                self.parseMediaHUD?.label.text = NSLocalizedString("解析弹幕中...", comment: "")
            case .subtitle(_):
                self.parseMediaHUD?.progress = 0.9
                self.parseMediaHUD?.label.text = NSLocalizedString("加载字幕中...", comment: "")
            case .lastWatchProgress(let lastWatchProgress):
                self.parseMediaHUD?.progress = 1
                self.parseMediaHUD?.label.text = NSLocalizedString("即将开始播放...", comment: "")
                
                self.showGotoLastWatchTime(lastWatchProgress: lastWatchProgress)
            }
        case .error(let error):
            if let error = error as? PlayerModel.ParseError {
                switch error {
                case .matched(let collection, let media):
                    let vc = MatchsViewController(with: collection, file: media)
                    vc.delegate = self
                    self.navigationController?.pushViewController(vc, animated: true)
                case .notMatchedDanmaku:
                    self.view.showError(error)
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
    private func showGotoLastWatchTime(lastWatchProgress: TimeInterval, retryTime: Int = 0) {
        let totalTime = self.mediaModel.length
        
        if totalTime == 0 && retryTime < 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showGotoLastWatchTime(lastWatchProgress: lastWatchProgress, retryTime: retryTime + 1)
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
                
                self.playerModel.changePosition(lastWatchProgress)
                self.uiView.autoShowControlView()
            }
            
            customView.show(from: self.view)
            self.gotoLastWatchPointView = customView
        } else {
            if let path = self.mediaModel.media?.url.path {
                ANX.logError(.UI, "视频时长获取失败 \(path)")
            }
        }
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PlayerViewController: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerDidStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        ANX.logInfo(.player, "[PiP] PiP 窗口已显示")
        mediaModel.pipManager?.handlePiPStarted()
        showPiPOverlay()
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        ANX.logInfo(.player, "[PiP] PiP 窗口已关闭")
        mediaModel.pipManager?.handlePiPStopped()
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler
        completion: @escaping (Bool) -> Void
    ) {
        ANX.logInfo(.player, "[PiP] 恢复用户界面")
        mediaModel.pipManager?.handleRestoreUI(completion: completion)
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        ANX.logError(.player, "[PiP] 启动失败: \(error)")
        mediaModel.pipManager?.handlePiPStopped()
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

@available(iOS 15.0, *)
extension PlayerViewController: AVPictureInPictureSampleBufferPlaybackDelegate {

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {
        ANX.logInfo(.player, "[PiP] 用户\(playing ? "播放" : "暂停")")
        mediaModel.pipManager?.handleSetPlaying(playing)
    }

    func pictureInPictureControllerIsPlaybackPaused(
        _ controller: AVPictureInPictureController
    ) -> Bool {
        return mediaModel.pipManager?.isPlaying == false
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        skipByInterval interval: CMTime,
        completion: @escaping () -> Void
    ) {
        mediaModel.pipManager?.handleSkip(by: interval.seconds, completion: completion)
    }

    func pictureInPictureControllerTimeRangeForPlayback(
        _ controller: AVPictureInPictureController
    ) -> CMTimeRange {
        return mediaModel.pipManager?.handleTimeRangeRequest()
            ?? CMTimeRange(start: .zero, duration: CMTime(seconds: pipFallbackDuration, preferredTimescale: pipTimescale))
    }

    func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(
        _ controller: AVPictureInPictureController
    ) -> Bool {
        return false
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {
        // 渲染尺寸变化，PiPManager 内部处理 layer 布局即可，无需额外操作
    }
}

// MARK: - PiPOverlayView

private class PiPOverlayView: UIView {

    var onTap: (() -> Void)?

    private let label: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("画中画模式", comment: "")
        label.textColor = .white
        label.font = .systemFont(ofSize: 18)
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?()
    }
}
