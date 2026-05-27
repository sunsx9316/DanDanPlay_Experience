//
//  PlayerViewController.swift
//  AniXPlayer
//
//  tvOS 播放器 — PlayerModel 串联 match → danmaku → play 全流程 + Siri Remote 事件
//

import UIKit
import SnapKit
import RxSwift
import ANXLog

class PlayerViewController: ViewController {

    // MARK: - Properties

    private lazy var playerModel = PlayerModel()
    private var mediaModel: PlayerMediaModel { playerModel.mediaModel }
    private var danmakuModel: PlayerDanmakuModel { playerModel.danmakuModel }

    private let bag = DisposeBag()
    private let sidePanelAnimator = SidePanelAnimator()
    private let centerPopupAnimator = CenterPopupAnimator()

    private var seekStep: Double = 10
    private var loadingView: PlayerLoadingView?
    private var gotoLastWatchPointVC: GotoLastWatchPointViewController?
    
    private var seekTimer: Timer?
    private var seekDirection: Double = 0
    private var seekPreviewTime: Double?

    // MARK: - UI

    private var mediaView: UIView {
        return mediaModel.mediaView
    }

    private lazy var danmakuCanvas: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        return view
    }()

    private lazy var overlayView = PlayerOverlayView()

    private let miniProgressBar = PlayerProgressBar(
        trackColor: UIColor(white: 0.3, alpha: 0.6),
        cornerRadius: 0
    )

    private var seekToast: PlayerToastView?
    private weak var fastSeekToast: PlayerToastView?

    // MARK: - Init

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

    private var firstPlayMediaCallBack: (() -> File?)?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black

        view.addSubview(mediaView)
        view.addSubview(danmakuCanvas)
        danmakuCanvas.addSubview(danmakuModel.danmakuView)
        view.addSubview(overlayView)

        mediaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        danmakuCanvas.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        danmakuModel.danmakuView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(miniProgressBar)

        miniProgressBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(5)
        }

        overlayView.onShow = { [weak self] in self?.miniProgressBar.isHidden = true }
        overlayView.onHide = { [weak self] in self?.miniProgressBar.isHidden = false }

        overlayView.onAutoHide = { [weak self] in
            self?.overlayView.hide()
        }

        overlayView.bottomBar.onDanmakuTapped = { [weak self] in
            self?.showDanmakuInput()
            self?.overlayView.resetAutoHideTimer()
        }

        overlayView.bottomBar.onSettingsTapped = { [weak self] in
            self?.showSettings()
            self?.overlayView.resetAutoHideTimer()
        }

        overlayView.bottomBar.onPlaylistTapped = { [weak self] in
            self?.showPlaylist()
            self?.overlayView.resetAutoHideTimer()
        }

        let leftTap = UITapGestureRecognizer(target: self, action: #selector(handleLeftArrow))
        leftTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        view.addGestureRecognizer(leftTap)

        let rightTap = UITapGestureRecognizer(target: self, action: #selector(handleRightArrow))
        rightTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        view.addGestureRecognizer(rightTap)

        let leftLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLeftLongPress(_:)))
        leftLongPress.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        leftLongPress.minimumPressDuration = 0.8
        view.addGestureRecognizer(leftLongPress)

        let rightLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleRightLongPress(_:)))
        rightLongPress.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        rightLongPress.minimumPressDuration = 0.8
        view.addGestureRecognizer(rightLongPress)

        bindModel()
        overlayView.show()

        if let firstPlayMedia = self.firstPlayMediaCallBack?() {
            playerModel.tryParseMedia(firstPlayMedia)
        }
    }

    @objc private func handleLeftArrow() {
        if overlayView.isVisible {
            overlayView.resetAutoHideTimer()
        } else {
            seek(by: -seekStep)
        }
    }

    @objc private func handleRightArrow() {
        if overlayView.isVisible {
            overlayView.resetAutoHideTimer()
        } else {
            seek(by: seekStep)
        }
    }

    @objc private func handleLeftLongPress(_ gesture: UILongPressGestureRecognizer) {
        handleLongPress(gesture, direction: -1)
    }

    @objc private func handleRightLongPress(_ gesture: UILongPressGestureRecognizer) {
        handleLongPress(gesture, direction: 1)
    }

    private func handleLongPress(_ gesture: UILongPressGestureRecognizer, direction: Double) {
        switch gesture.state {
        case .began:
            seekDirection = direction
            seekPreviewTime = mediaModel.currentTime
            if seekToast == nil {
                seekToast = PlayerToastView.show(in: view, text: "", dismissAfter: nil)
            }
            startSeekTimer()
        case .ended, .cancelled:
            if let previewTime = seekPreviewTime {
                seekToTime(previewTime)
            }
            stopSeekTimer()
            seekPreviewTime = nil
            seekToast?.dismiss()
            seekToast = nil
        default:
            break
        }
    }

    private func startSeekTimer() {
        seekTimer?.invalidate()
        seekTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            guard let self = self, let previewTime = self.seekPreviewTime else { return }
            let totalLength = self.mediaModel.length
            let newTime = max(0, min(previewTime + self.seekDirection * self.seekStep * 2, totalLength))
            self.seekPreviewTime = newTime
            self.updateSeekPreview(newTime, total: totalLength)
        }
    }

    private func stopSeekTimer() {
        seekTimer?.invalidate()
        seekTimer = nil
    }

    private func updateSeekPreview(_ time: Double, total: Double) {
        overlayView.bottomBar.currentTimeText = formatTime(time)
        let fraction = total > 0 ? CGFloat(time / total) : 0
        overlayView.bottomBar.progressFraction = fraction
        miniProgressBar.progressFraction = fraction

        seekToast?.updateText("\(formatTime(time)) / \(formatTime(total))")
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        guard overlayView.isVisible else { return super.preferredFocusEnvironments }
        return [overlayView.bottomBar.playlistButton, overlayView.bottomBar.danmakuButton, overlayView.bottomBar.settingsButton]
    }

    deinit {
        seekTimer?.invalidate()
        playerModel.mediaModel.terminate()
    }

    // MARK: - Progress Timer

    private func updateProgress(_ current: TimeInterval, total: TimeInterval) {
        overlayView.bottomBar.currentTimeText = formatTime(current)
        overlayView.bottomBar.totalTimeText = formatTime(total)

        let fraction = total > 0 ? CGFloat(current / total) : 0
        overlayView.bottomBar.progressFraction = fraction
        miniProgressBar.progressFraction = fraction
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Siri Remote / Press Events

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else {
            super.pressesEnded(presses, with: event)
            return
        }

        switch press.type {
        case .playPause:
            togglePlayPause()

        case .select:
            handleSelectPress()

        default:
            super.pressesEnded(presses, with: event)
        }
    }

    private func handleSelectPress() {
        if !overlayView.isVisible {
            overlayView.show()
            setNeedsFocusUpdate()
            updateFocusIfNeeded()
        }
        overlayView.resetAutoHideTimer()
    }

    // MARK: - Playback Control

    private func togglePlayPause() {
        let newState = mediaModel.changePlayState()
        let text = newState == .playing ?  NSLocalizedString("暂停", comment: "") : NSLocalizedString("播放", comment: "")
        PlayerToastView.show(in: view, text: text)
    }

    private func seek(by seconds: Double, showToast: Bool = true) {
        let currentTime = mediaModel.currentTime
        let totalLength = mediaModel.length
        let newTime = max(0, min(currentTime + seconds, totalLength))
        let position = totalLength > 0 ? newTime / totalLength : 0
        playerModel.changePosition(CGFloat(position))
        updateProgress(currentTime, total: totalLength)

        if showToast {
            let direction = seconds > 0 ? ">>" : "<<"
            let timeString = formatTime(newTime)
            
            if self.fastSeekToast == nil {
                self.fastSeekToast = PlayerToastView.show(in: view, text: "", dismissAfter: nil)
            }
            
            self.fastSeekToast?.updateText("\(direction) \(abs(Int(seconds)))s\n\(timeString)")
            self.fastSeekToast?.dismiss(after: 1)
        }
    }

    private func seekToTime(_ time: Double) {
        let totalLength = mediaModel.length
        let position = totalLength > 0 ? time / totalLength : 0
        playerModel.changePosition(CGFloat(position))
        updateProgress(time, total: totalLength)
    }

    private func showSettings() {
        let vc = PlayerSettingViewController(playerModel: playerModel)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .custom
        nav.transitioningDelegate = sidePanelAnimator
        present(nav, animated: true)
    }

    private func showDanmakuInput() {
        mediaModel.changePlayState() // 暂停播放

        let vc = DanmakuInputViewController()

        vc.onSend = { [weak self] text, mode, color in
            self?.sendDanmaku(text: text, mode: mode, color: color)
        }

        vc.onDismiss = { [weak self] in
            self?.mediaModel.changePlayState() // 恢复播放
        }

        vc.modalPresentationStyle = .overCurrentContext
        present(vc, animated: true)
    }

    private func showPlaylist() {
        let currentMedia = mediaModel.media
        let directory = currentMedia?.parentFile ?? LocalFile.rootFile
        let fileBrowserVC = FileBrowserViewController(directory: directory)
        fileBrowserVC.filterType = .video
        fileBrowserVC.highlightedFile = currentMedia
        fileBrowserVC.delegate = self
        let nav = UINavigationController(rootViewController: fileBrowserVC)
        nav.modalPresentationStyle = .custom
        nav.transitioningDelegate = sidePanelAnimator
        present(nav, animated: true)
    }

    private func sendDanmaku(text: String, mode: Comment.Mode, color: ANXColor) {
        guard let item = mediaModel.media,
              let matchInfo = mediaModel.matchInfo(media: item),
              matchInfo.matchId > 0 else {
            let alert = UIAlertController(
                title: nil,
                message: NSLocalizedString("需要指定视频弹幕列表，才能发弹幕哟~", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
            present(alert, animated: true)
            return
        }

        var comment = Comment()
        comment.time = danmakuModel.currentTime
        comment.mode = mode
        comment.color = color
        comment.message = text

        danmakuModel.sendDanmaku(matchId: matchInfo.matchId, danmaku: comment) { [weak self] success, msg in
            DispatchQueue.main.async {
                if success {
                    ANX.logInfo(.player, "[PlayerVC] 弹幕发送成功")
                } else if let msg = msg {
                    let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    // MARK: - PlayerModel Bindings

    private func bindModel() {
        playerModel.parseMediaState.subscribe(onNext: { [weak self] event in
            guard let self = self else { return }
            self.handleMediaLoadEvent(event)
        }).disposed(by: bag)

        mediaModel.context.media.subscribe(onNext: { [weak self] file in
            guard let self = self else { return }
            self.overlayView.topBar.title = file?.fileName
        }).disposed(by: bag)

        mediaModel.context.time.subscribe(onNext: { [weak self] timeInfo in
            if self?.seekTimer == nil {
                // 长按快进/快退 不更新进度
                self?.updateProgress(timeInfo.currentTime, total: timeInfo.totalTime)
            }
        }).disposed(by: bag)

        mediaModel.context.isPlay.subscribe(onNext: { isPlay in
            UIApplication.shared.isIdleTimerDisabled = isPlay
        }).disposed(by: bag)

        mediaModel.context.buffer.subscribe(onNext: { _ in
            // buffer 更新可扩展
        }).disposed(by: bag)

        mediaModel.context.subtitleSafeArea.subscribe(onNext: { [weak self] subtitleSafeArea in
            guard let self = self else { return }
            self.danmakuCanvas.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                if subtitleSafeArea {
                    make.height.equalToSuperview().multipliedBy(0.85)
                } else {
                    make.height.equalToSuperview()
                }
            }
        }).disposed(by: bag)

        danmakuModel.context.isShowDanmaku.subscribe(onNext: { [weak self] isShow in
            ANX.logInfo(.player, "[PlayerVC] 弹幕开关: \(isShow)")
            self?.danmakuCanvas.isHidden = !isShow
        }).disposed(by: bag)

        danmakuModel.context.danmakuAlpha.subscribe(onNext: { [weak self] danmakuAlpha in
            guard let self = self else { return }
            self.danmakuCanvas.alpha = CGFloat(danmakuAlpha)
        }).disposed(by: bag)

        danmakuModel.context.danmakuArea.subscribe(onNext: { [weak self] danmakuArea in
            guard let self = self else { return }
            self.danmakuModel.danmakuView.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.height.equalToSuperview().multipliedBy(danmakuArea.value)
            }
        }).disposed(by: bag)

        danmakuModel.context.danmakuArea.skip(1).subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
            UIView.animate(withDuration: 0.2) {
                self.danmakuModel.danmakuView.backgroundColor = UIColor.mainColor.withAlphaComponent(0.7)
            } completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    self.danmakuModel.danmakuView.backgroundColor = .clear
                }
            }
        }).disposed(by: bag)
    }

    private func handleMediaLoadEvent(_ event: RxSwift.Event<PlayerModel.MediaLoadState>) {
        switch event {
        case .next(let state):
            if loadingView == nil {
                let lv = PlayerLoadingView()
                view.addSubview(lv)
                lv.snp.makeConstraints { make in make.edges.equalToSuperview() }
                loadingView = lv
            }

            switch state {
            case .parse(let loadingState, let progress):
                let text: String
                switch loadingState {
                case .parseMedia:
                    text = NSLocalizedString("解析媒体中...", comment: "")
                case .downloadLocalDanmaku:
                    text = NSLocalizedString("加载本地弹幕中...", comment: "")
                case .matchMedia:
                    text = NSLocalizedString("匹配弹幕中...", comment: "")
                case .downloadDanmaku:
                    text = NSLocalizedString("下载弹幕中...", comment: "")
                }
                loadingView?.update(text: text, progress: 0.8 * Float(progress))
            case .filterDanmaku(let progress):
                loadingView?.update(text: NSLocalizedString("解析弹幕中...", comment: ""), progress: 0.8 + 0.05 * Float(progress))
            case .subtitle:
                loadingView?.update(text: NSLocalizedString("加载字幕中...", comment: ""), progress: 0.9)
            case .lastWatchProgress(let progress):
                loadingView?.update(text: NSLocalizedString("即将开始播放...", comment: ""), progress: 1.0)
                loadingView?.dismiss()
                loadingView = nil
                showGotoLastWatchTime(lastWatchProgress: progress)
            }

        case .error(let error):
            loadingView?.dismiss()
            loadingView = nil
            handleParseError(error)

        case .completed:
            loadingView?.dismiss()
            loadingView = nil
        }
    }

    private func handleParseError(_ error: Error) {
        if let parseError = error as? PlayerModel.ParseError {
            switch parseError {
            case .matched(let collection, let media):
                let vc = MatchsViewController(collection: collection, media: media, playerModel: playerModel, style: .full)
                vc.delegate = self
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = .custom
                nav.transitioningDelegate = sidePanelAnimator
                present(nav, animated: true)
            case .notMatchedDanmaku:
                let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
                present(alert, animated: true)
            }
        } else {
            let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - Last Watch Progress

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

            self.gotoLastWatchPointVC?.dismiss()

            let vc = GotoLastWatchPointViewController()
            vc.timeString = NSLocalizedString("上次观看时间：", comment: "") + lastTimeString()
            vc.didClickGotoButton = { [weak self] in
                guard let self = self else { return }

                self.playerModel.changePosition(lastWatchProgress)
                self.overlayView.show()
            }

            vc.modalPresentationStyle = .custom
            vc.transitioningDelegate = centerPopupAnimator
            present(vc, animated: true)
            self.gotoLastWatchPointVC = vc
        }
    }
}

// MARK: - MatchsViewControllerDelegate

extension PlayerViewController: MatchsViewControllerDelegate {
    func matchsViewController(_ matchsViewController: MatchsViewController, didMatched matchInfo: any MatchInfo) {
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.handleMatchResult(matchInfo)
            }
        }
    }

    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController) {
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                _ = self.playerModel.startPlay(self.playerModel.mediaModel.media!, matchInfo: nil, danmakus: [:]).subscribe()
            }
        }
    }

    private func handleMatchResult(_ matchInfo: any MatchInfo) {
        guard let media = playerModel.mediaModel.media else { return }
        ANX.logInfo(.player, "[PlayerVC] 弹幕匹配成功: \(matchInfo.matchDesc)")
        _ = playerModel.didMatchMedia(media, matchInfo: matchInfo).subscribe()
    }
}

// MARK: - FileBrowserViewControllerDelegate

extension PlayerViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile file: File, allFiles: [File]) {
        presentedViewController?.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.mediaModel.loadMedias(allFiles)
            self.playerModel.tryParseMedia(file)
        }
    }
}
