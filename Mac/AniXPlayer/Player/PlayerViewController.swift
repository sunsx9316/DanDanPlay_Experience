//
//  PlayerViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/8.
//

import Cocoa
import SnapKit
import Carbon
import RxSwift
import ANXLog
import AVKit

class PlayerViewController: ViewController {

    var onStopCallBack: (() -> Void)?

    /// 当前媒体变化（独立播放器窗口用于同步标题）。
    var onMediaChanged: ((File?) -> Void)?

    private lazy var dragView: DragView = {
        let view = DragView()
        view.dragFilesCallBack = { [weak self] urls in
            guard let self = self else { return }

            self.loadFiles(urls)
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
    
    lazy var playerModel = PlayerModel()
    
    private var danmakuModel: PlayerDanmakuModel {
        return self.playerModel.danmakuModel
    }
    
    private var mediaModel: PlayerMediaModel {
        return self.playerModel.mediaModel
    }
    
    
    private lazy var disposeBag = DisposeBag()

    private weak var gotoLastWatchPointView: GotoLastWatchPointView?

    private weak var snapshotPreviewView: SnapshotPreviewView?

    /// 进度条缩略图缓存（key = 秒）
    private var thumbnailCache = [Int: ANXImage]()
    

    /// 弹幕画布容器
    private lazy var danmakuCanvas: NSView = {
        let view = BaseView()
        view.wantsLayer = true
        return view
    }()
    
    private var matchWindowController: WindowController?

    private let playHistoryReporter = PlayHistoryReporter()

    private weak var danmakuMenu: NSMenu?

    private var sendDanmakuColor: ANXColor = Preferences.shared.sendDanmakuColor
    private var sendDanmakuMode: Comment.Mode = .normal

    /// 会员补充弹幕门禁；由集成方注入会员检查/付费墙。默认放行。
    var backupDanmakuAccessCheck: () async -> Bool = { true }

    /// 会员动图导出（GIF）门禁；由集成方注入会员检查/付费墙。默认放行。
    var gifExportAccessCheck: () async -> Bool = { true }

    private var isLoadingBackupDanmaku = false
    private var isExportingGIF = false
    private var gifExportFlow: GIFExportFlowController?

    // 开始活动以防止系统休眠
    private var activityToken: NSObjectProtocol?

    /// 从“继续播放”打开时指定的进度（0...1）；优先于 HistoryManager 的上次进度。
    private var pendingSeekProgress: Double?

    //MARK: - life cycle
    
    deinit {
        self.closeMatchWindow()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        self.gifExportFlow?.cancelAndDismiss()

        if self.mediaModel.isPlaying {
            self.playerModel.mediaModel.pause()
        }
        
        self.endActivity()
    }
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 800, height: 600))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        self.view.setAccessibilityIdentifier(AccessibilityID.Player.root)
        self.mediaModel.mediaView.setAccessibilityIdentifier(AccessibilityID.Player.mediaView)
        self.danmakuCanvas.setAccessibilityIdentifier(AccessibilityID.Player.danmakuCanvas)
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
            ANX.logInfo(.player, "[Player] 键盘切换全屏")
            self.onToggleFullScreen()
        case kVK_Space:
            ANX.logInfo(.player, "[Player] 键盘空格播放/暂停")
            self.mediaModel.changePlayState()
        case kVK_LeftArrow, kVK_RightArrow:
            let shortJumpValue: Int32 = 5

            let jumpTime = keyCode == kVK_LeftArrow ? TimeInterval(-shortJumpValue) : TimeInterval(shortJumpValue)
            ANX.logInfo(.player, "[Player] 键盘方向键跳转: \(jumpTime)s")
            self.playerModel.changePosition(diffValue: jumpTime)
        case kVK_UpArrow, kVK_DownArrow:
            let volumeAddingValue: CGFloat = 20

            let volumeValue = keyCode == kVK_DownArrow ? -volumeAddingValue : volumeAddingValue
            ANX.logInfo(.player, "[Player] 键盘方向键音量: \(volumeValue)")
            self.mediaModel.onChangeVolume(volumeValue)
        default:
            super.keyDown(with: event)
        }
    }
    
    /// L2 播放冒烟：读取当前播放状态。
    func playbackSnapshot() -> PlaybackSnapshot {
        let media = mediaModel.media
        return PlaybackSnapshot(
            title: media?.fileName,
            duration: max(mediaModel.length, 0),
            position: max(mediaModel.currentTime, 0),
            isPlaying: mediaModel.isPlaying,
            danmakuCount: danmakuModel.danmakuList.count,
            playerReady: media != nil && mediaModel.length > 0
        )
    }

    /// 欢迎页“最近播放”使用：当前正在播放的媒体。
    var currentMediaFile: File? {
        return mediaModel.media
    }

    /// 停止播放；独立播放器窗口关闭时调用。
    func stopPlayback() {
        gifExportFlow?.cancelAndDismiss()
        mediaModel.stop()
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
        self.mediaModel.context.miniProgressBar.subscribe(onNext: { [weak self] isOn in
            self?.uiView.miniProgressEnabled = isOn
        }).disposed(by: self.disposeBag)

        self.mediaModel.context.media.subscribe(onNext: { [weak self] file in
            guard let self = self else { return }

            // 切换媒体时取消正在进行的动图导出，避免抓到上一个视频或卡住进度 sheet。
            self.gifExportFlow?.cancelAndDismiss()
            self.uiView.title = file?.fileName
            self.onMediaChanged?(file)
            self.playHistoryReporter.reset()
            if file != nil {
                self.beginActivity()
            } else {
                self.endActivity()
            }
        }).disposed(by: self.disposeBag)
        
        self.mediaModel.context.time.subscribe(onNext: { [weak self] timeInfo in
            guard let self = self else { return }

            self.uiView.updateTime()
            if let episodeId = self.playerModel.currentMatchInfo?.matchId {
                self.playHistoryReporter.reportIfNeeded(
                    episodeId: episodeId,
                    currentTime: timeInfo.currentTime
                )
            }
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
        
        self.mediaModel.context.volume.subscribe(onNext: { [weak self] volume in
            guard let self = self else { return }
            
            self.view.show(text: NSLocalizedString("音量: ", comment: "") + "\(volume)")
        }).disposed(by: self.disposeBag)
        
        self.mediaModel.context.playList.subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
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

    /// 会员补充弹幕：重新拉取 withRelated 弹幕，去重后喂给渲染器。
    private func requestBackupDanmaku() {
        guard !self.isLoadingBackupDanmaku else { return }

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            guard await self.backupDanmakuAccessCheck() else {
                ANX.logInfo(.player, "[Player] 补充弹幕：未通过会员门禁")
                self.view.show(text: NSLocalizedString("补充弹幕是弹弹play会员功能", comment: ""))
                return
            }

            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                return
            }

            guard let media = self.mediaModel.media,
                  let matchInfo = self.playerModel.currentMatchInfo ?? self.mediaModel.matchInfo(media: media),
                  matchInfo.matchId > 0 else {
                ANX.logInfo(.player, "[Player] 补充弹幕：当前视频没有匹配信息，无法补充")
                self.view.show(text: NSLocalizedString("当前视频没有匹配到弹幕库，无法补充弹幕", comment: ""))
                return
            }

            self.isLoadingBackupDanmaku = true
            defer { self.isLoadingBackupDanmaku = false }

            self.view.showLoading(statusText: NSLocalizedString("正在补充弹幕…", comment: ""))
            do {
                let result = try await BackupDanmakuService.shared.reloadAssociatedDanmaku(
                    episodeId: matchInfo.matchId,
                    existing: self.currentDanmakuMap()
                )
                _ = self.danmakuModel.setupDanmaku(result.danmakus).subscribe()

                if result.addedCount > 0 {
                    self.view.show(
                        text: String(
                            format: NSLocalizedString("新增 %d 条弹幕", comment: ""),
                            result.addedCount
                        )
                    )
                } else {
                    self.view.show(text: NSLocalizedString("没有可补充的弹幕", comment: ""))
                }
            } catch {
                ANX.logError(.player, "[Player] 补充弹幕失败：\(error)")
                self.view.show(error: error)
            }
        }
    }

    private func currentDanmakuMap() -> DanmakuMapResult {
        var map = DanmakuMapResult()
        for entity in self.danmakuModel.danmakuList {
            let time = entity.rawComment?.time ?? entity.originAppearTime ?? entity.appearTime
            let bucket = UInt(max(0, time.rounded(.down)))
            map[bucket, default: []].append(entity)
        }
        return map
    }
    
    /// 批量加载文件并开始播放
    func loadFiles(_ files: [File], startWith file: File? = nil, progress: Double? = nil) {
        self.pendingSeekProgress = progress
        if !files.isEmpty {
            self.mediaModel.loadMedias(files)
            self.playerModel.tryParseMedia(file ?? files[0])
        }
    }

    @objc private func pickFile() {
        let currentPlayItem = self.mediaModel.media ?? LocalFile.rootFile
        type(of: currentPlayItem).fileManager.pickFiles(currentPlayItem.parentFile, from: self, filterType: .all) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let files):
                if files.count == 1, let file = files.first {
                    if file.url.isSubtitleFile {
                        _ = self.mediaModel.loadSubtitleByUser(file).subscribe(onError: { [weak self] error in
                            self?.view.show(error: error)
                        }, onCompleted: { [weak self] in
                            self?.view.show(text: NSLocalizedString("加载本地字幕成功！", comment: ""))
                        })
                    } else if file.url.isDanmakuFile {
                        _ = self.danmakuModel.loadDanmakuByUser(file).subscribe(onError: { [weak self] error in
                            self?.view.show(error: error)
                        }, onCompleted: { [weak self] in
                            self?.view.show(text: NSLocalizedString("加载本地弹幕成功！", comment: ""))
                        })
                    }
                }
            case .failure:
                break
            }
        }
    }
}

// MARK: - MatchsViewControllerDelegate
extension PlayerViewController: MatchsViewControllerDelegate {
    
    func matchsViewController(_ matchsViewController: MatchsViewController, didMatched matchInfo: any MatchInfo) {
        self.closeMatchWindow()
        
        _ = self.playerModel.didMatchMedia(matchsViewController.file, matchInfo: matchInfo).subscribe { [weak self] event in
            guard let self = self else { return }
            
            self.parseMedia(event: event)
        }
    }
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController) {
        self.closeMatchWindow()
        _ = self.playerModel.startPlay(matchsViewController.file, matchInfo: nil, danmakus: [:]).subscribe()
    }
    
    /// 解析视频
    /// - Parameters:
    ///   - event: 解析事件
    ///   - hud: 指示器
    private func parseMedia(event: RxSwift.Event<PlayerModel.MediaLoadState>) {

        let hud = self.view.showProgress()

        switch event {
        case .next(let element):
            switch element {
            case .parse(let state, let progress):

                hud.progress = Float(0.8 * progress)

                switch state {
                case .parseMedia:
                    hud.labelText = NSLocalizedString("开始解析...", comment: "")
                case .downloadLocalDanmaku:
                    hud.labelText = NSLocalizedString("下载本地弹幕...", comment: "")
                case .matchMedia(progress: _):
                    hud.labelText = NSLocalizedString("解析视频中...", comment: "")
                case .downloadDanmaku:
                    hud.labelText = NSLocalizedString("加载弹幕中...", comment: "")
                }
            case .filterDanmaku(progress: _):
                hud.progress = 0.85
                hud.labelText = NSLocalizedString("解析弹幕中...", comment: "")
            case .subtitle(_):
                hud.progress = 0.9
                hud.labelText = NSLocalizedString("加载字幕中...", comment: "")
            case .lastWatchProgress(let lastWatchProgress):
                hud.progress = 1
                hud.labelText = NSLocalizedString("即将开始播放...", comment: "")

                if let pendingSeekProgress = self.pendingSeekProgress {
                    self.pendingSeekProgress = nil
                    // 用户从“继续播放”明确选择了一个进度：直接跳转，不再弹上次进度提示。
                    self.seekToProgress(pendingSeekProgress)
                } else {
                    self.showGotoLastWatchTime(lastWatchProgress: lastWatchProgress)
                }
            }
        case .error(let error):
            self.view.dismiss()
            if let error = error as? PlayerModel.ParseError {
                switch error {
                case .matched(let collection, let media):
                    self.popMatchWindowController(with: collection, file: media)
                case .notMatchedDanmaku:
                    self.view.show(error: error)
                }
            } else {
                self.view.show(error: error)
            }
        case .completed:
            self.view.dismiss(delay: 0.3)
        }
    }
    
    
    /// 跳到指定进度（0...1）。播放器时长可能稍后才就绪，最多重试约 5 秒。
    private func seekToProgress(_ progress: Double, retryTime: Int = 0) {
        guard self.mediaModel.length > 0 else {
            if retryTime < 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.seekToProgress(progress, retryTime: retryTime + 1)
                }
            }
            return
        }

        self.playerModel.changePosition(CGFloat(max(0, min(progress, 1))))
        self.uiView.autoShowControlView()
    }

    /// 显示上次播放进度
    /// - Parameters:
    ///   - lastWatchProgress: 上次播放进度
    ///   - retryTime: 重试次数
    private func showGotoLastWatchTime(lastWatchProgress: TimeInterval, retryTime: Int = 0) {
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
    
    private func beginActivity() {
        self.activityToken = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .suddenTerminationDisabled], reason: "Playing video")
    }
    
    private func endActivity() {
        // 停止活动以允许系统休眠
        if let token = self.activityToken {
            ProcessInfo.processInfo.endActivity(token)
        }
    }
}

// MARK: - PlayerUIViewDataSource
extension PlayerViewController: PlayerUIViewDataSource {
    
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
extension PlayerViewController: PlayerUIViewDelegate, NSMenuDelegate {

    /// 会员动图导出：先展示选项 sheet，再抓帧/编码，支持进度与取消。
    /// 本地文件优先 AVFoundation；其它/失败时回退无头 MPV；在线源使用 MPV 与 httpHeaders。
    func exportGIF() {
        guard !isExportingGIF else { return }
        guard let item = mediaModel.media else {
            self.view.show(text: NSLocalizedString("请先打开视频", comment: ""))
            return
        }
        guard item.createMPVMedia() != nil else {
            self.view.show(text: NSLocalizedString("当前视频暂不支持导出动图", comment: ""))
            return
        }

        let startTime = mediaModel.currentTime
        let duration = mediaModel.length
        guard duration > 0, startTime < duration - GIFExportConfiguration.minimumClipDuration else {
            self.view.show(text: NSLocalizedString("当前位置之后没有足够的视频内容", comment: ""))
            return
        }

        isExportingGIF = true
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            guard await self.gifExportAccessCheck() else {
                self.isExportingGIF = false
                return
            }

            // 门禁/付费墙期间用户可能已经切换媒体。
            guard let current = self.mediaModel.media, current === item else {
                self.isExportingGIF = false
                return
            }

            let flow = GIFExportFlowController(
                host: self,
                file: item,
                startTime: startTime,
                mediaDuration: duration
            )
            flow.onFinish = { [weak self] in
                self?.gifExportFlow = nil
                self?.isExportingGIF = false
            }
            self.gifExportFlow = flow
            flow.start()
        }
    }

    func onTouchThumbnailerButton(playerUIView: PlayerUIView) {
        ANX.logInfo(.player, "[Player] 点击截图")

        self.playerModel.mediaModel.onFetchThumbnail { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let image):
                ANX.logInfo(.player, "[Player] 截图成功")

                let preview = self.showSnapshotPreview(image: image)
                self.saveSnapshot(image: image, fileName: self.snapshotFileName(), preview: preview)
            case .failure(let error):
                ANX.logError(.player, "[Player] 截图失败: \(error)")
                self.view.show(text: NSLocalizedString("截图失败", comment: ""))
            }
        }
    }

    /// 在播放器右侧展示截图预览
    /// - Parameter image: 截图
    /// - Returns: 预览视图，便于外部更新提示文案
    @discardableResult
    private func showSnapshotPreview(image: NSImage) -> SnapshotPreviewView? {
        let preview: SnapshotPreviewView
        if let aPreview = self.snapshotPreviewView {
            preview = aPreview
        } else {
            preview = SnapshotPreviewView()
            self.snapshotPreviewView = preview
        }

        preview.tipText = NSLocalizedString("正在保存...", comment: "")
        preview.show(image: image, from: self.view)
        return preview
    }

    /// 进度条预览：按需生成指定进度的缩略图（带缓存）
    func playerUIView(_ playerUIView: PlayerUIView, requestThumbnailAt progress: CGFloat, completion: @escaping (ANXImage?) -> Void) {
        let totalTime = self.mediaModel.length
        guard totalTime > 0 else {
            completion(nil)
            return
        }

        let second = Int(Double(progress) * totalTime)
        if let image = self.thumbnailCache[second] {
            completion(image)
            return
        }

        self.playerModel.mediaModel.fetchThumbnail(at: Float(progress)) { [weak self] result in
            guard let self = self else { return }

            if case .success(let image) = result {
                self.cacheThumbnail(image, forKey: second)
                completion(image)
            } else {
                completion(nil)
            }
        }
    }

    private func cacheThumbnail(_ image: ANXImage, forKey key: Int) {
        if self.thumbnailCache.count >= 200 {
            self.thumbnailCache.removeAll()
        }
        self.thumbnailCache[key] = image
    }

    /// 保存截图；若因沙盒权限失败，则引导用户重新选择目录后重试
    private func saveSnapshot(image: NSImage, fileName: String, preview: SnapshotPreviewView?) {
        image.saveSnapshot(fileName: fileName) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let url):
                ANX.logInfo(.player, "[Player] 截图已保存: \(url.path)")
                preview?.tipText = String(format: NSLocalizedString("已保存：%@", comment: ""), url.lastPathComponent)
                preview?.didClickReveal = {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            case .failure(let error):
                ANX.logError(.player, "[Player] 截图保存失败: \(error)")
                if self.isSnapshotPermissionError(error) {
                    preview?.dismiss()
                    self.promptSnapshotDirectory(image: image, fileName: fileName)
                } else {
                    preview?.dismiss()
                    self.view.show(text: NSLocalizedString("截图保存失败", comment: ""))
                }
            }
        }
    }

    private func isSnapshotPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteNoPermissionError
    }

    /// 没有权限时提示用户重新选择保存位置，并重试
    private func promptSnapshotDirectory(image: NSImage, fileName: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("无法保存截图", comment: "")
        alert.informativeText = NSLocalizedString("没有权限保存到当前目录，请重新选择保存位置。", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("选择文件夹…", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("选择", comment: "")
        panel.directoryURL = SnapshotLocation.currentDirectoryURL
        guard panel.runModal() == .OK, let url = panel.url else { return }

        SnapshotLocation.saveBookmark(for: url)
        Preferences.shared.snapshotDirectory = url.path

        // 用新目录重试保存
        let preview = self.showSnapshotPreview(image: image)
        self.saveSnapshot(image: image, fileName: fileName, preview: preview)
    }

    /// 生成截图文件名：视频名 + 时间戳
    private func snapshotFileName() -> String {
        let sourceName = self.mediaModel.media?.fileName ?? "Snapshot"
        let baseName = (sourceName as NSString).deletingPathExtension

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"

        let name = "\(baseName)_\(formatter.string(from: Date()))"
        /// 过滤文件名中的非法字符
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
    
    func onTouchDanmakuSettingButton(playerUIView: PlayerUIView, button: NSButton) {
        ANX.logInfo(.player, "[Player] 打开弹幕设置")
        self.dismissPresented()

        let vc = DanmakuSettingViewController(danmakuModel: self.danmakuModel)
        vc.delegate = self

        self.present(vc, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }

    func onTouchMediaSettingButton(playerUIView: PlayerUIView, button: NSButton) {
        ANX.logInfo(.player, "[Player] 打开媒体设置")
        self.dismissPresented()

        let vc = MediaSettingViewController(mediaModel: self.mediaModel)
        vc.delegate = self
        self.present(vc, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }
    
    func playerUIView(_ playerUIView: PlayerUIView, didChangeControlViewState show: Bool) {

    }
    
    func onTouchPlayerList(playerUIView: PlayerUIView, button: NSButton) {
        ANX.logInfo(.player, "[Player] 打开播放列表")
        self.dismissPresented()

        let vc = PlayerListViewController()
        vc.delegate = self
        self.present(vc, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }

    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool) {
        ANX.logInfo(.player, "[Player] 弹幕开关: \(isOn ? "开启" : "关闭")")
        self.danmakuCanvas.isHidden = !isOn
    }

    func onTouchSendDanmakuButton(playerUIView: PlayerUIView) {
    }

    func onTouchDanmakuConfigButton(playerUIView: PlayerUIView, button: NSButton) {
        ANX.logInfo(.player, "[Player] 打开弹幕配置")
        dismissPresented()

        let vc = SendDanmakuViewController(color: sendDanmakuColor, mode: sendDanmakuMode)
        vc.onColorChanged = { [weak self] color in
            self?.sendDanmakuColor = color
        }
        vc.onModeChanged = { [weak self] mode in
            self?.sendDanmakuMode = mode
        }
        present(vc, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }

    func playerUIView(_ playerUIView: PlayerUIView, didPressEnterInDanmakuTextField textField: NSTextField) {
        let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let item = self.mediaModel.media, self.mediaModel.isMatch(media: item),
              let matchId = self.mediaModel.matchInfo(media: item)?.matchId else {
            self.view.show(text: NSLocalizedString("需要指定视频弹幕列表，才能发弹幕哟~", comment: ""))
            return
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                return
            }

            var comment = Comment()
            comment.message = text
            comment.mode = self.sendDanmakuMode
            comment.color = self.sendDanmakuColor
            comment.time = self.mediaModel.currentTime

            ANX.logInfo(.player, "[Player] 发送弹幕: \"\(text)\" mode=\(comment.mode) color=\(comment.color)")
            self.danmakuModel.sendDanmaku(matchId: matchId, danmaku: comment) { [weak self] success, msg in
                DispatchQueue.main.async {
                    self?.view.show(text: msg ?? "")
                    if success {
                        textField.stringValue = ""
                    }
                }
            }
        }
    }
    
    func onTouchPlayButton(playerUIView: PlayerUIView, isSelected: Bool) {
        ANX.logInfo(.player, "[Player] 点击播放按钮")
        self.mediaModel.changePlayState()
    }

    func doubleTap(playerUIView: PlayerUIView) {
        ANX.logInfo(.player, "[Player] 双击切换全屏")
        self.onToggleFullScreen()
    }

    func onTouchStopButton(playerUIView: PlayerUIView) {
        ANX.logInfo(.player, "[Player] 点击停止按钮")
        // 先回调保存进度，再停止播放（stop 可能清空位置）。
        onStopCallBack?()
        self.mediaModel.stop()
    }

    func onTouchNextButton(playerUIView: PlayerUIView) {
        if let media = self.mediaModel.nextMedia() {
            ANX.logInfo(.player, "[Player] 切换下一集: \(media.fileName)")
            self.playerModel.tryParseMedia(media)
        } else {
            ANX.logInfo(.player, "[Player] 没有下一集")
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
    
    func menuDidClose(_ menu: NSMenu) {
        if menu == self.danmakuMenu {
            self.danmakuModel.deselectDanmaku()            
        }
    }
    
    func onClickRightMouse(playerUIView: PlayerUIView, at point: NSPoint) {
        let pointInDanmakuCanvas = self.danmakuCanvas.convert(point, from: playerUIView)
        if let danmakuCanvas = self.danmakuModel.selectedDanmaku(at: pointInDanmakuCanvas) {
            /// 命中弹幕，弹出气泡
            ANX.logInfo(.player, "[Player] 右键点击弹幕")
            let menu = NSMenu(title: NSLocalizedString("操作弹幕", comment: ""))
            menu.delegate = self
            self.danmakuMenu = menu
            menu.addItem(NSMenuItem(title: NSLocalizedString("复制弹幕", comment: ""), action: { [weak self] _ in
                self?.danmakuModel.copyDanmkuText(danmakuCanvas)
                ANX.logInfo(.player, "[Player] 复制弹幕")
            }))
            menu.addItem(NSMenuItem(title: NSLocalizedString("屏蔽弹幕", comment: ""), action: { [weak self] _ in
                self?.danmakuModel.onAddFilterDanmku(danmakuCanvas)
                ANX.logInfo(.player, "[Player] 屏蔽该弹幕")
            }))

            menu.popUp(positioning: nil, at: pointInDanmakuCanvas, in: self.danmakuCanvas)
        }
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
        ANX.logInfo(.player, "[Player] 从播放列表选择: \(file.fileName)")
        self.playerModel.tryParseMedia(file)
    }

    func playerListViewController(_ viewController: PlayerListViewController, didDeleteRow: Int) {
        let file = self.mediaModel.playList[didDeleteRow]
        ANX.logInfo(.player, "[Player] 从播放列表删除: \(file.fileName)")
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
    
    func filterDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        let vc = FilterDanmakuViewController(danmakuModel: self.danmakuModel)
        self.presentAsModalWindow(vc)
    }

    func showDanmakuListInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        // Mac 端暂不支持弹幕列表展示
    }

    func backupDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        self.dismissPresented()
        self.requestBackupDanmaku()
    }
}

// MARK: - MediaSettingViewControllerDelegate
extension PlayerViewController: MediaSettingViewControllerDelegate {
    
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController) {
        self.pickFile()
    }
    
}
