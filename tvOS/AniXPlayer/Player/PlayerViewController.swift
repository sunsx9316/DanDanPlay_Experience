//
//  PlayerViewController.swift
//  AniXPlayer
//
//  tvOS 播放器 — VLC 视频渲染 + Siri Remote 事件 + 控制栏
//

import UIKit
import SnapKit
import RxSwift

class PlayerViewController: ViewController {

    // MARK: - Properties

    var file: File? {
        didSet {
            guard let file = file else { return }
            mediaPlayer.play(file)
        }
    }

    private let mediaPlayer = MediaPlayer(coreType: .vlc)
    private let bag = DisposeBag()

    private var isControlBarVisible = true
    private var autoHideTimer: Timer?
    private var seekStep: Double = 10

    // MARK: - UI

    private lazy var mediaView: UIView = {
        return mediaPlayer.mediaView
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
        view.addSubview(controlBar)
        view.addSubview(seekHUDLabel)

        mediaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        controlBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(120)
        }

        seekHUDLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        setupPlayerCallbacks()
        showControlBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = controlBar
    }

    deinit {
        mediaPlayer.stop()
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
            // Don't consume — let focused button handle if control bar is visible

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
                // Long press → show speed menu
                showSpeedMenu()
            } else if !controlBarHasFocus {
                // Short press with no control focus → toggle control bar
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
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
    }

    private func seek(by seconds: Double) {
        let currentTime = mediaPlayer.currentTime
        let totalLength = mediaPlayer.length
        let newTime = max(0, min(currentTime + seconds, totalLength))
        let position = totalLength > 0 ? newTime / totalLength : 0
        mediaPlayer.setPosition(position)
        showSeekHUD(seconds: seconds)
    }

    private func dismissPlayer() {
        autoHideTimer?.invalidate()
        mediaPlayer.pause()
        self.dismiss(animated: true)
    }

    private func toggleDanmaku(_ isOn: Bool) {
        // tvOS danmaku limited — skip for now
    }

    private func showSettings() {
        let vc = UIAlertController(title: NSLocalizedString("播放设置", comment: ""), message: nil, preferredStyle: .alert)
        vc.addAction(UIAlertAction(title: NSLocalizedString("倍速", comment: ""), style: .default) { [weak self] _ in
            self?.showSpeedMenu()
        })
        vc.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        present(vc, animated: true)
    }

    private func showSpeedMenu() {
        let vc = UIAlertController(title: NSLocalizedString("播放倍速", comment: ""), message: nil, preferredStyle: .actionSheet)
        for speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0] {
            vc.addAction(UIAlertAction(title: "\(speed)x", style: .default) { [weak self] _ in
                self?.mediaPlayer.speed = speed
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

    // MARK: - Player Callbacks

    private func setupPlayerCallbacks() {
        mediaPlayer.delegate = self
    }
}

// MARK: - MediaPlayerDelegate

extension PlayerViewController: MediaPlayerDelegate {

    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {}

    func player(_ player: MediaPlayer, stateDidChange state: PlayerState) {
        DispatchQueue.main.async { [weak self] in
            self?.controlBar.updatePlayState(isPlaying: state == .playing)
        }
    }

    func player(_ player: MediaPlayer, shouldChangeMedia media: File) -> Bool {
        return true
    }

    func player(_ player: MediaPlayer, file: File, bufferInfoDidChange bufferInfo: MediaBufferInfo) {}

    func playerListDidChange(_ player: MediaPlayer) {}
}
