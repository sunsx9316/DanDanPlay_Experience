//
//  PlayerControlBar.swift
//  AniXPlayer
//
//  tvOS 播放器控制栏 — 焦点驱动按钮
//

import UIKit
import SnapKit

class PlayerControlBar: UIView {

    // MARK: - Callbacks

    var onPlayPause: (() -> Void)?
    var onSeekForward: (() -> Void)?
    var onSeekBackward: (() -> Void)?
    var onSettings: (() -> Void)?
    var onDanmakuToggle: ((Bool) -> Void)?
    var onStepChange: ((Double) -> Void)?

    // MARK: - UI

    private lazy var playPauseButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(playPauseTapped), for: .primaryActionTriggered)
        return btn
    }()

    private lazy var seekBackwardButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "gobackward.10"), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(seekBackwardTapped), for: .primaryActionTriggered)
        return btn
    }()

    private lazy var seekForwardButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "goforward.10"), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(seekForwardTapped), for: .primaryActionTriggered)
        return btn
    }()

    private lazy var settingsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(settingsTapped), for: .primaryActionTriggered)
        return btn
    }()

    private lazy var stepLabel: UILabel = {
        let label = UILabel()
        label.text = "10s"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        return label
    }()

    private let blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .dark)
        return UIVisualEffectView(effect: effect)
    }()

    private var isPlaying = false

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let stackView = UIStackView(arrangedSubviews: [
            seekBackwardButton, playPauseButton, seekForwardButton,
            settingsButton, stepLabel,
        ])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 40
        stackView.distribution = .equalSpacing

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(10)
        }

        for btn in [seekBackwardButton, playPauseButton, seekForwardButton, settingsButton] {
            btn.snp.makeConstraints { make in
                make.size.equalTo(CGSize(width: 60, height: 60))
            }
        }

        // Focusable items
        let focusGuide = UIFocusGuide()
        addLayoutGuide(focusGuide)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [playPauseButton]
    }

    // MARK: - Actions

    @objc private func playPauseTapped() {
        isPlaying.toggle()
        updatePlayButtonIcon()
        onPlayPause?()
    }

    @objc private func seekBackwardTapped() {
        onSeekBackward?()
    }

    @objc private func seekForwardTapped() {
        onSeekForward?()
    }

    @objc private func settingsTapped() {
        onSettings?()
    }

    // MARK: - Public

    func updatePlayState(isPlaying: Bool) {
        self.isPlaying = isPlaying
        updatePlayButtonIcon()
    }

    private func updatePlayButtonIcon() {
        let icon = isPlaying ? UIImage(systemName: "pause.fill") : UIImage(systemName: "play.fill")
        playPauseButton.setImage(icon, for: .normal)
    }
}
