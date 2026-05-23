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

    var file: File? {
        didSet {
            guard let file = file else { return }
            playerModel.tryParseMedia(file)
        }
    }

    private lazy var playerModel = PlayerModel()
    private var mediaModel: PlayerMediaModel { playerModel.mediaModel }
    private var danmakuModel: PlayerDanmakuModel { playerModel.danmakuModel }

    private let bag = DisposeBag()
    private let sidePanelAnimator = SidePanelAnimator()

    private var seekStep: Double = 10
    private var loadingView: PlayerLoadingView?
    private var progressTimer: Timer?

    // MARK: - UI

    private lazy var mediaView: UIView = {
        return mediaModel.mediaView
    }()

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

    // MARK: - Lifecycle

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

        let leftTap = UITapGestureRecognizer(target: self, action: #selector(handleLeftArrow))
        leftTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        view.addGestureRecognizer(leftTap)

        let rightTap = UITapGestureRecognizer(target: self, action: #selector(handleRightArrow))
        rightTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        view.addGestureRecognizer(rightTap)

        bindModel()
        startProgressTimer()
    }

    @objc private func handleLeftArrow() {
        guard presentedViewController == nil, !overlayView.isVisible else { return }
        seek(by: -seekStep)
    }

    @objc private func handleRightArrow() {
        guard presentedViewController == nil, !overlayView.isVisible else { return }
        seek(by: seekStep)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        guard overlayView.isVisible else { return super.preferredFocusEnvironments }
        return [overlayView.bottomBar.danmakuButton, overlayView.bottomBar.settingsButton]
    }

    deinit {
        progressTimer?.invalidate()
        playerModel.mediaModel.terminate()
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func updateProgress() {
        let current = mediaModel.currentTime
        let total = mediaModel.length
        overlayView.topBar.title = file?.fileName
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

    private func seek(by seconds: Double) {
        let currentTime = mediaModel.currentTime
        let totalLength = mediaModel.length
        let newTime = max(0, min(currentTime + seconds, totalLength))
        let position = totalLength > 0 ? newTime / totalLength : 0
        playerModel.changePosition(CGFloat(position))
        updateProgress()

        let direction = seconds > 0 ? ">>" : "<<"
        PlayerToastView.show(in: view, text: "\(direction) \(abs(Int(seconds)))s")
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
            case .lastWatchProgress:
                loadingView?.update(text: NSLocalizedString("即将开始播放...", comment: ""), progress: 1.0)
                loadingView?.dismiss()
                loadingView = nil
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
