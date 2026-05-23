//
//  PlayerUIBottomView.swift
//  AniXPlayer
//
//  tvOS 播放器底部控制栏 — 进度条 + 时间 + 弹幕 + 设置按钮
//

import UIKit
import SnapKit

class PlayerUIBottomView: UIView {

    // MARK: - Progress

    var progressFraction: CGFloat = 0 {
        didSet { progressBar.progressFraction = progressFraction }
    }

    var currentTimeText: String = "00:00" {
        didSet { currentTimeLabel.text = currentTimeText }
    }

    var totalTimeText: String = "00:00" {
        didSet { totalTimeLabel.text = totalTimeText }
    }

    // MARK: - Focusable elements（外部只读）

    private(set) lazy var danmakuButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("弹幕", comment: ""), for: .normal)
        button.titleLabel?.font = .ddp_small(weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.black, for: .focused)
        return button
    }()

    private(set) lazy var settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("设置", comment: ""), for: .normal)
        button.titleLabel?.font = .ddp_small(weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.black, for: .focused)
        return button
    }()

    // MARK: - Callbacks

    var onDanmakuTapped: (() -> Void)?
    var onSettingsTapped: (() -> Void)?

    // MARK: - UI

    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.4)
        return view
    }()

    private let progressBar = PlayerProgressBar(
        trackColor: UIColor(white: 0.3, alpha: 1.0),
        cornerRadius: 3
    )

    private let currentTimeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .ddp_small(monospaced: true)
        label.text = "00:00"
        return label
    }()

    private let totalTimeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .ddp_small(monospaced: true)
        label.text = "00:00"
        return label
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(backgroundView)
        addSubview(progressBar)
        addSubview(currentTimeLabel)
        addSubview(totalTimeLabel)
        addSubview(settingsButton)
        addSubview(danmakuButton)

        settingsButton.addTarget(self, action: #selector(settingsPressed), for: .primaryActionTriggered)
        danmakuButton.addTarget(self, action: #selector(danmakuPressed), for: .primaryActionTriggered)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        settingsButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-80)
            make.centerY.equalTo(progressBar)
        }

        danmakuButton.snp.makeConstraints { make in
            make.trailing.equalTo(settingsButton.snp.leading).offset(-30)
            make.centerY.equalTo(progressBar)
        }

        progressBar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalTo(danmakuButton.snp.leading).offset(-20)
            make.centerY.equalToSuperview().offset(-4)
            make.height.equalTo(6)
        }

        currentTimeLabel.snp.makeConstraints { make in
            make.leading.equalTo(progressBar)
            make.top.equalTo(progressBar.snp.bottom).offset(8)
        }

        totalTimeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(progressBar)
            make.top.equalTo(progressBar.snp.bottom).offset(8)
        }
    }

    @objc private func danmakuPressed() {
        onDanmakuTapped?()
    }

    @objc private func settingsPressed() {
        onSettingsTapped?()
    }
}
