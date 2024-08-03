//
//  PlayerViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/8.
//

import Cocoa
import SnapKit
import Carbon
import ProgressHUD
import RxSwift

class PlayerViewController: ViewController {
    
    private lazy var dragView: DragView = {
        let view = DragView()
        view.dragFilesCallBack = { [weak self] urls in
            guard let self = self else { return }
            
            self.openURLs(urls)
        }
            
        return view
    }()
    
    private lazy var uiView: PlayerUIView = {
        let view = PlayerUIView()
        view.delegate = self
        view.dataSource = self
        
        let trackingArea = NSTrackingArea(rect: self.view.bounds, options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)
        view.addTrackingArea(trackingArea)
        
        return view
    }()
    
    private lazy var containerView: NSView = {
        let view = BaseView()
        return view
    }()
    
    private lazy var playerModel = PlayerModel()
    
    private var danmakuModel: PlayerDanmakuModel {
        return self.playerModel.danmakuModel
    }
    
    private var mediaModel: PlayerMediaModel {
        return self.playerModel.mediaModel
    }
    
    
    private lazy var disposeBag = DisposeBag()
    
    private weak var gotoLastWatchPointView: GotoLastWatchPointView?
    

    /// 弹幕画布容器
    private lazy var danmakuCanvas: NSView = {
        let view = BaseView()
        view.wantsLayer = true
        return view
    }()
    
    private var matchWindowController: WindowController?
    
    //MARK: - life cycle
    
    deinit {
        self.closeMatchWindow()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        
        if self.mediaModel.isPlaying {
            self.playerModel.mediaModel.pause()
        }
        
        self.mediaModel.storeProgress()
    }
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 800, height: 600))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        self.view.addSubview(self.dragView)
        self.dragView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.mediaModel.mediaView)
        self.containerView.addSubview(self.danmakuCanvas)
        self.view.addSubview(self.uiView)
        self.danmakuCanvas.addSubview(self.danmakuModel.danmakuView)
        
        self.containerView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.mediaModel.mediaView.frame = self.view.bounds
        self.mediaModel.mediaView.autoresizingMask = [.maxYMargin, .maxXMargin, .width, .height]
        
        self.uiView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.bindModel()
        self.uiView.autoShowControlView()
        self.setupMenu()
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        self.uiView.autoShowControlView()
    }
    
    override func keyDown(with event: NSEvent) {
        let keyCode = Int(event.keyCode)
        
        switch keyCode {
        case kVK_Tab:
            break
        case kVK_Return:
            self.onToggleFullScreen()
        case kVK_Space:
            self.mediaModel.changePlayState()
        case kVK_LeftArrow, kVK_RightArrow:
            let shortJumpValue: Int32 = 5
            
            let jumpTime = keyCode == kVK_LeftArrow ? TimeInterval(-shortJumpValue) : TimeInterval(shortJumpValue)
            self.playerModel.changePosition(diffValue: jumpTime)
        case kVK_UpArrow, kVK_DownArrow:
            let volumeAddingValue: CGFloat = 20
            
            let volumeValue = keyCode == kVK_DownArrow ? -volumeAddingValue : volumeAddingValue
            self.mediaModel.onChangeVolume(volumeValue)
        default:
            super.keyDown(with: event)
        }
    }
    
    //MARK: - Private
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
        }).disposed(by: self.disposeBag)
        
//        self.mediaModel.context.buffer.subscribe(onNext: { [weak self] bufferInfos in
//            guard let self = self else { return }
            
//            self.uiView.updateBufferInfos(bufferInfos ?? [])
//        }).disposed(by: self.disposeBag)
        
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
            
            let animate = CAKeyframeAnimation(keyPath: #keyPath(CALayer.backgroundColor))
            let mainColor = NSColor.mainColor
            animate.values = [
                NSColor(red: mainColor.redComponent, green: mainColor.greenComponent, blue: mainColor.blueComponent, alpha: 0.3).cgColor,
                NSColor.clear.cgColor
            ]
            animate.duration = 0.5
            animate.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.danmakuCanvas.layer?.add(animate, forKey: "CAKeyframeAnimation")
            
        }).disposed(by: self.disposeBag)
        
        self.mediaModel.context.volume.skip(1).subscribe(onNext: { [weak self] volume in
            guard let self = self else { return }
            
            self.view.show(text: NSLocalizedString("音量: ", comment: "") + "\(volume)")
        }).disposed(by: self.disposeBag)
        
        self.mediaModel.context.playList.subscribe(onNext: { [weak self] playList in
            guard let self = self else { return }
            
            self.uiView.showOpenButton = !(playList?.isEmpty == false)
        }).disposed(by: self.disposeBag)
    }
    
    
    private func bindDanmakuModel() {
        self.danmakuModel.context.danmakuAlpha.subscribe(onNext: { [weak self] danmakuAlpha in
            guard let self = self else { return }
            
            self.danmakuCanvas.alphaValue = CGFloat(danmakuAlpha)
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
            
            let animate = CAKeyframeAnimation(keyPath: #keyPath(CALayer.backgroundColor))
            let mainColor = NSColor.mainColor
            animate.values = [
                NSColor(red: mainColor.redComponent, green: mainColor.greenComponent, blue: mainColor.blueComponent, alpha: 0.3).cgColor,
                NSColor.clear.cgColor
            ]
            animate.duration = 0.5
            animate.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.danmakuModel.danmakuView.layer?.add(animate, forKey: "CAKeyframeAnimation")
            
        }).disposed(by: self.disposeBag)
        
    }
    
    private func popMatchWindowController(with collection: MatchCollection?, file: File) {
        
        self.matchWindowController?.close()
        
        let vc: MatchsViewController
        
        if let collection = collection {
            vc = .init(with: collection, file: file)
        } else {
            vc = MatchsViewController(file: file)
        }
        
        vc.delegate = self
        
        self.matchWindowController = WindowController()
        self.matchWindowController?.contentViewController = vc
        self.matchWindowController?.showAtCenter(self.view.window)
        self.matchWindowController?.window?.title = vc.title ?? ""
        self.matchWindowController?.window?.level = .floating
        self.matchWindowController?.windowWillCloseCallBack = { [weak self] in
            guard let self = self else { return }
            
            self.matchWindowController = nil
        }
    }
    
    private func onToggleFullScreen() {
        let window = view.window
        window?.collectionBehavior = .fullScreenPrimary
        window?.toggleFullScreen(nil)
    }
    
    private func dismissPresented() {
        let presentedViewControllers = self.presentedViewControllers
        if presentedViewControllers?.isEmpty == false {
            presentedViewControllers?.forEach({ vc in
                vc.dismiss(nil)
            })
        }
    }
    
    private func closeMatchWindow() {
        self.matchWindowController?.close()
        self.matchWindowController = nil
    }
    
    private func setupMenu() {
        if let fileItem = NSApp.appDelegate?.fileMenu?.item(withTag: MenuTag.fileOpen.rawValue) {
            fileItem.target = self
            fileItem.action = #selector(pickFile)
        }
    }
    
    /// 文件拾取器
    @objc private func pickFile() {
        
        let currentPlayItem = self.mediaModel.media ?? LocalFile.rootFile

        type(of: currentPlayItem).fileManager.pickFiles(currentPlayItem.parentFile, from: self, filterType: .all) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let files):
                if files.count == 1 && files[0].url.isSubtitleFile {
                    _ = self.mediaModel.loadSubtitleByUser(files[0]).subscribe(onError: { [weak self] error in
                        guard let self = self else { return }
                        
                        self.view.show(error: error)
                    }, onCompleted: { [weak self] in
                        guard let self = self else { return }
                        
                        self.view.show(text: NSLocalizedString("加载本地字幕成功！", comment: ""))
                    })
                } else if files.count == 1 && files[0].url.isDanmakuFile {
                    _ = self.danmakuModel.loadDanmakuByUser(files[0]).subscribe(onError: { [weak self] error in
                        guard let self = self else { return }
                        
                        self.view.show(error: error)
                    }, onCompleted: { [weak self] in
                        guard let self = self else { return }
                        
                        self.view.show(text: NSLocalizedString("加载本地弹幕成功！", comment: ""))
                    })
                } else {
                    self.openURLs(files)
                }
            case .failure(_):
                break
            }
            
        }
    }
    
    @objc private func openDanmakuFiles(_ item: NSMenuItem) {
        
    }
    
    /// 批量加载url
    /// - Parameter urls: url集合
    private func openURLs(_ files: [File]) {
        if !files.isEmpty {
            self.mediaModel.loadMedias(files)
            self.playerModel.tryParseMedia(files[0])
        }
    }
}

// MARK: - MatchsViewControllerDelegate
extension PlayerViewController: MatchsViewControllerDelegate {
    
    func matchsViewController(_ matchsViewController: MatchsViewController, didSelectedEpisodeId episodeId: Int) {
        
        self.closeMatchWindow()
        
        _ = self.playerModel.didMatchMedia(matchsViewController.file, episodeId: episodeId).subscribe { [weak self] event in
            guard let self = self else { return }
            
            self.parseMedia(event: event)
        }
    }
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController) {
        self.closeMatchWindow()
        _ = self.playerModel.startPlay(matchsViewController.file, episodeId: 0, danmakus: [:])
    }
    
    /// 解析视频
    /// - Parameters:
    ///   - event: 解析事件
    ///   - hud: 指示器
    private func parseMedia(event: RxSwift.Event<PlayerModel.MediaLoadState>) {
        
        let builder = self.view.showProgress()
        
        switch event {
        case .next(let element):
            switch element {
            case .parse(let state, let progress):
                
                builder.progress = CGFloat(progress)
                
                switch state {
                case .parseMedia:
                    builder.statusText = NSLocalizedString("开始解析...", comment: "")
                case .downloadLocalDanmaku:
                    builder.statusText = NSLocalizedString("下载本地弹幕...", comment: "")
                case .matchMedia(progress: _):
                    builder.statusText = NSLocalizedString("解析视频中...", comment: "")
                case .downloadDanmaku:
                    builder.statusText = NSLocalizedString("加载弹幕中...", comment: "")
                }
                
            case .subtitle(_):
                builder.progress = 0.85
                builder.statusText = NSLocalizedString("加载字幕中...", comment: "")
            case .lastWatchProgress(let lastWatchProgress):
                builder.progress = 1
                builder.statusText = NSLocalizedString("即将开始播放...", comment: "")
                
                self.showGotoLastWatchTime(lastWatchProgress: lastWatchProgress, retryTime: 0)
            }
        case .error(let error):
            if let error = error as? PlayerModel.ParseError {
                switch error {
                case .notMatched(let collection, let media):
                    self.popMatchWindowController(with: collection, file: media)
                }
            } else {
                self.view.show(error: error)
            }
            
            self.view.dismiss(delay: 0.3)
        case .completed:
            self.view.dismiss(delay: 0.3)
        }
    }
    
    
    /// 显示上次播放进度
    /// - Parameters:
    ///   - lastWatchProgress: 上次播放进度
    ///   - retryTime: 重试次数
    private func showGotoLastWatchTime(lastWatchProgress: TimeInterval, retryTime: Int) {
        let totalTime = self.mediaModel.length
        
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
                
                self.playerModel.changePosition(lastWatchProgress)
                self.uiView.autoShowControlView()
            }
            
            customView.show(from: self.view)
            self.gotoLastWatchPointView = customView
        } else {
            if let url = self.mediaModel.media?.url {
                ANX.logError(.UI, "视频时长获取失败 \(url)")
            }
        }
    }
}

// MARK: - PlayerUIViewDataSource
extension PlayerViewController: PlayerUIViewDataSource {
    func playerMediaThumbnailer(playerUIView: PlayerUIView) -> MediaThumbnailer? {
        return nil
    }
    
    func playerCurrentTime(playerUIView: PlayerUIView) -> TimeInterval {
        return mediaModel.currentTime
    }
    
    func playerTotalTime(playerUIView: PlayerUIView) -> TimeInterval {
        return mediaModel.length
    }
    
    func playerProgress(playerUIView: PlayerUIView) -> CGFloat {
        return CGFloat(mediaModel.position)
    }
}

// MARK: - PlayerUIViewDelegate
extension PlayerViewController: PlayerUIViewDelegate {
    
    func openButtonDidClick(playerUIView: PlayerUIView, button: NSButton) {
        self.pickFile()
    }
    
    func onTouchDanmakuSettingButton(playerUIView: PlayerUIView, button: NSButton) {
        self.dismissPresented()
        
        let vc = DanmakuSettingViewController(danmakuModel: self.danmakuModel)
        vc.delegate = self
        
        self.present(vc, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }
    
    func onTouchMediaSettingButton(playerUIView: PlayerUIView, button: NSButton) {
        self.dismissPresented()
        
        let vc = MediaSettingViewController(mediaModel: self.mediaModel)
        vc.delegate = self
        self.present(vc, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }
    
    func playerUIView(_ playerUIView: PlayerUIView, didChangeControlViewState show: Bool) {
        
    }
    
    func onTouchPlayerList(playerUIView: PlayerUIView, button: NSButton) {
        self.dismissPresented()
        
        let vc = PlayerListViewController()
        vc.delegate = self
        self.present(vc, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }
    
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool) {
        self.danmakuCanvas.isHidden = !isOn
    }
    
    func onTouchSendDanmakuButton(playerUIView: PlayerUIView) {
        guard let item = self.mediaModel.media, self.mediaModel.isMatch(media: item) else {
            self.view.show(text: NSLocalizedString("需要指定视频弹幕列表，才能发弹幕哟~", comment: ""))
            return
        }
        
//        let vc = SendDanmakuViewController()
//        vc.onTouchSendButtonCallBack = { [weak self] (text, aVC) in
//            guard let self = self else { return }
//
//            guard let item = self.player.currentPlayItem,
//                  let _ = self.findPlayItem(item)?.episodeId else {
//
//                self.view.showHUD("需要指定视频弹幕列表，才能发弹幕哟~")
//                return
//            }
//
////            if !text.isEmpty {
////                let danmaku = DanmakuModel()
////                danmaku.mode = .normal
////                danmaku.time = self.danmakuRender.currentTime + self.danmakuRender.offsetTime
////                danmaku.message = text
////                danmaku.id = "\(Date().timeIntervalSince1970)"
////
////                let msg = SendDanmakuMessage()
////                msg.danmaku = danmaku
////                msg.episodeId = episodeId
////                #warning("待处理")
//////                MessageHandler.sendMessage(msg)
////
//////                self.danmakuRender.sendDanmaku(DanmakuManager.shared.conver(danmaku))
////            }
//
//            aVC.navigationController?.popViewController(animated: true)
//        }
//        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func onTouchPlayButton(playerUIView: PlayerUIView, isSelected: Bool) {
        self.mediaModel.changePlayState()
    }
    
    func doubleTap(playerUIView: PlayerUIView) {
        self.onToggleFullScreen()
    }
    
    func onTouchNextButton(playerUIView: PlayerUIView) {
        if let media = self.mediaModel.nextMedia() {
            self.playerModel.tryParseMedia(media)
        }
    }
    
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat) {
        self.playerModel.changePosition(progress)
    }
    
    func changeProgress(playerUIView: PlayerUIView, diffValue: CGFloat) {
        self.playerModel.changePosition(diffValue: diffValue)
    }
}

// MARK: - PlayerListViewControllerDelegate
extension PlayerViewController: PlayerListViewControllerDelegate {
    func numberOfRowAtPlayerListViewController() -> Int {
        return self.mediaModel.playList.count
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, titleAtRow: Int) -> String {
        return self.mediaModel.playList[titleAtRow].fileName
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, didSelectedRow: Int) {
        self.dismissPresented()
        
        let file = self.mediaModel.playList[didSelectedRow]
        self.playerModel.tryParseMedia(file)
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, didDeleteRow: Int) {
        let file = self.mediaModel.playList[didDeleteRow]
        self.mediaModel.removeMediaFromPlayList(file)
    }
    
    func currentPlayIndexAtPlayerListViewController(_ viewController: PlayerListViewController) -> Int? {
        return self.mediaModel.playList.firstIndex(where: { $0.url == self.mediaModel.media?.url })
    }
}

// MARK: - DanmakuSettingViewControllerDelegate
extension PlayerViewController: DanmakuSettingViewControllerDelegate {
    
    func searchDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        self.dismissPresented()
        
        if let item = self.mediaModel.media ?? self.mediaModel.playList.first {
            self.popMatchWindowController(with: nil, file: item)
        }
    }
    
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        self.pickFile()
    }
}

// MARK: - MediaSettingViewControllerDelegate
extension PlayerViewController: MediaSettingViewControllerDelegate {
    
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController) {
        self.pickFile()
    }
    
}
