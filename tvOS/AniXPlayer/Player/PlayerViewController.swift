//
//  PlayerViewController.swift
//  AniXPlayer
//
//  tvOS 播放器 — PlayerModel 串联 match → danmaku → play 全流程 + Siri Remote 事件 + 控制栏
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

    private var isControlBarVisible = true
    private var autoHideTimer: Timer?
    private var seekStep: Double = 10
    private var loadingView: PlayerLoadingView?

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

    private lazy var controlBar: PlayerControlBar = {
        let bar = PlayerControlBar()
        bar.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        bar.onSeekForward = { [weak self] in
            self?.seek(by: self?.seekStep ?? 10)
        }
        bar.onSeekBackward = { [weak self] in
            self?.seek(by: -(self?.seekStep ?? 10))
        }
        bar.onSettings = { [weak self] in
            self?.showSettings()
        }
        bar.onDanmakuToggle = { [weak self] isOn in
            self?.toggleDanmaku(isOn)
        }
        bar.onStepChange = { [weak self] step in
            self?.seekStep = step
        }
        bar.alpha = 0
        return bar
    }()

    private let seekHUDLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 36, weight: .medium)
        label.textAlignment = .center
        label.alpha = 0
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black

        view.addSubview(mediaView)
        view.addSubview(danmakuCanvas)
        danmakuCanvas.addSubview(danmakuModel.danmakuView)
        view.addSubview(controlBar)
        view.addSubview(seekHUDLabel)

        mediaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        danmakuCanvas.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        danmakuModel.danmakuView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        controlBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(120)
        }

        seekHUDLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        bindModel()
        showControlBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = controlBar
    }

    deinit {
        playerModel.mediaModel.terminate()
    }

    // MARK: - Siri Remote / Press Events

    private var selectPressBeganTime: TimeInterval = 0

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else {
            super.pressesBegan(presses, with: event)
            return
        }

        switch press.type {
        case .select:
            selectPressBeganTime = Date().timeIntervalSince1970

        case .menu:
            dismissPlayer()

        case .playPause:
            togglePlayPause()

        default:
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else {
            super.pressesEnded(presses, with: event)
            return
        }

        switch press.type {
        case .select:
            let duration = Date().timeIntervalSince1970 - selectPressBeganTime

            if duration >= 1.0 {
                showSpeedMenu()
            } else if !controlBarHasFocus {
                if isControlBarVisible {
                    hideControlBar()
                } else {
                    showControlBar()
                }
            }
            selectPressBeganTime = 0

        default:
            super.pressesEnded(presses, with: event)
        }
    }

    override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else { return }

        switch press.type {
        case .leftArrow:
            if !isControlBarVisible { showControlBar() }
            seek(by: -seekStep)

        case .rightArrow:
            if !isControlBarVisible { showControlBar() }
            seek(by: seekStep)

        default:
            break
        }
    }

    private var controlBarHasFocus: Bool {
        guard let focusedView = UIScreen.main.focusedView else { return false }
        return focusedView === controlBar || controlBar.subviews.contains(where: { $0 === focusedView })
    }

    // MARK: - Playback Control

    private func togglePlayPause() {
        mediaModel.changePlayState()
    }

    private func seek(by seconds: Double) {
        let currentTime = mediaModel.currentTime
        let totalLength = mediaModel.length
        let newTime = max(0, min(currentTime + seconds, totalLength))
        let position = totalLength > 0 ? newTime / totalLength : 0
        playerModel.changePosition(CGFloat(position))
        showSeekHUD(seconds: seconds)
    }

    private func dismissPlayer() {
        autoHideTimer?.invalidate()
        mediaModel.pause()
        self.dismiss(animated: true)
    }

    private func toggleDanmaku(_ isOn: Bool) {
        danmakuModel.onChangeIsShowDanmaku(isOn)
    }

    private func showSettings() {
        let vc = UIAlertController(title: NSLocalizedString("播放设置", comment: ""), message: nil, preferredStyle: .alert)
        vc.addAction(UIAlertAction(title: NSLocalizedString("倍速", comment: ""), style: .default) { [weak self] _ in
            self?.showSpeedMenu()
        })
        vc.addAction(UIAlertAction(title: NSLocalizedString("弹幕开关", comment: ""), style: .default) { [weak self] _ in
            let isOn = self?.danmakuModel.isShowDanmaku ?? true
            self?.toggleDanmaku(!isOn)
        })
        vc.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        present(vc, animated: true)
    }

    private func showSpeedMenu() {
        let vc = UIAlertController(title: NSLocalizedString("播放倍速", comment: ""), message: nil, preferredStyle: .actionSheet)
        for speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0] {
            vc.addAction(UIAlertAction(title: "\(speed)x", style: .default) { [weak self] _ in
                self?.playerModel.changeSpeed(speed)
            })
        }
        vc.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        present(vc, animated: true)
    }

    // MARK: - Control Bar

    private func showControlBar() {
        isControlBarVisible = true
        UIView.animate(withDuration: 0.3) {
            self.controlBar.alpha = 1.0
        }
        resetAutoHideTimer()
    }

    private func hideControlBar() {
        isControlBarVisible = false
        UIView.animate(withDuration: 0.3) {
            self.controlBar.alpha = 0
        }
        autoHideTimer?.invalidate()
    }

    private func resetAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.hideControlBar()
        }
    }

    // MARK: - HUD

    private func showSeekHUD(seconds: Double) {
        let direction = seconds > 0 ? ">>" : "<<"
        seekHUDLabel.text = "\(direction) \(abs(Int(seconds)))s"
        seekHUDLabel.alpha = 1.0

        UIView.animate(withDuration: 1.0, delay: 0.5, options: [], animations: {
            self.seekHUDLabel.alpha = 0
        })
    }

    // MARK: - PlayerModel Bindings

    private func bindModel() {
        // 加载状态
        playerModel.parseMediaState.subscribe(onNext: { [weak self] event in
            guard let self = self else { return }
            self.handleMediaLoadEvent(event)
        }).disposed(by: bag)

        // 播放状态 → 控制栏
        mediaModel.context.isPlay.subscribe(onNext: { [weak self] isPlay in
            self?.controlBar.updatePlayState(isPlaying: isPlay)
        }).disposed(by: bag)

        // 弹幕开关
        danmakuModel.context.isShowDanmaku.subscribe(onNext: { [weak self] isShow in
            ANX.logInfo(.player, "[PlayerVC] 弹幕开关: \(isShow)")
            self?.danmakuCanvas.isHidden = !isShow
        }).disposed(by: bag)

        // 弹幕透明度
//        danmakuModel.context.danmakuAlpha.subscribe(onNext: { [weak self] alpha in
//            self?.danmakuCanvas.alpha = CGFloat(alpha)
//        }).disposed(by: bag)
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
                loadingView?.update(text: text)
            case .filterDanmaku:
                loadingView?.update(text: NSLocalizedString("解析弹幕中...", comment: ""))
            case .subtitle:
                loadingView?.update(text: NSLocalizedString("加载字幕中...", comment: ""))
            case .lastWatchProgress:
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
                let vc = MatchsViewController(collection: collection, media: media, playerModel: playerModel)
                self.present(vc, animated: true)
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
