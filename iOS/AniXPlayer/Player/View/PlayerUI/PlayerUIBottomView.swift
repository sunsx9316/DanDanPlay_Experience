//
//  PlayerUIBottomView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/6.
//

import UIKit
import SnapKit
import DynamicButton

class PlayerUIBottomView: UIView {

    lazy var progressSlider: ProgressSlider = {
        let slider = ProgressSlider()
        slider.thumbTintColor = UIColor.white
        slider.trackHighlightTintColor = .init(red: 2, green: 31, blue: 0)
        slider.thumbHitTestSlop = .init(top: -20, left: -50, bottom: -10, right: -50)
        slider.trackBufferColor = .init(red: 7, green: 109, blue: 0)
        slider.curvaceousness = 0.4
        return slider
    }()

    lazy var playButton: DynamicButton = {
        let button = DynamicButton(style: .pause)
        button.lineWidth = 6
        button.strokeColor = .white
        button.highlightStokeColor = .lightGray
        button.adjustsImageWhenHighlighted = true
        button.adjustsImageWhenDisabled = true
        return button
    }()

    lazy var nextButton: Button = {
        let button = Button(type: .custom)
        button.setImage(UIImage(named: "Player/play_next"), for: .normal)
        button.adjustsImageWhenHighlighted = true
        button.adjustsImageWhenDisabled = true
        return button
    }()

    lazy var timeLabel: Label = {
        let label = Label()
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    /// 弹幕输入框按钮（像输入框样式的按钮）
    lazy var danmakuInputButton: Button = {
        let button = Button(type: .custom)
        button.backgroundColor = UIColor(white: 0.2, alpha: 0.6)
        button.layer.cornerRadius = 18
        button.setTitle(NSLocalizedString("发个弹幕吧", comment: ""), for: .normal)
        button.setTitleColor(UIColor.lightGray, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.contentHorizontalAlignment = .left
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
        button.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        button.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
        return button
    }()

    lazy var playerListButton: Button = {
        let button = Button(type: .custom)
        button.setTitle(NSLocalizedString("选集", comment: ""), for: .normal)
        button.adjustsImageWhenHighlighted = true
        button.adjustsImageWhenDisabled = true
        return button
    }()

    private lazy var bgView: UIView = {
        let bgView = UIView()
        bgView.backgroundColor = UIColor(white: 0, alpha: 0.4)
        return bgView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }

    private func setupInit() {
        self.addSubview(self.bgView)
        let containerView = UIView()
        containerView.addSubview(self.progressSlider)
        containerView.addSubview(self.playButton)
        containerView.addSubview(self.nextButton)
        containerView.addSubview(self.timeLabel)
        containerView.addSubview(self.danmakuInputButton)
        containerView.addSubview(self.playerListButton)
        self.addSubview(containerView)

        self.bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.snp.makeConstraints { make in
            make.leading.equalTo(self.safeAreaLayoutGuide.snp.leading)
            make.trailing.equalTo(self.safeAreaLayoutGuide.snp.trailing)
            make.bottom.equalTo(self.safeAreaLayoutGuide.snp.bottom)
            make.top.equalToSuperview()
        }

        self.progressSlider.snp.makeConstraints { make in
            make.top.leading.equalTo(0)
            make.trailing.equalTo(-10)
            make.height.equalTo(30)
        }

        self.playButton.snp.makeConstraints { make in
            make.leading.equalTo(self.progressSlider)
            make.bottom.equalToSuperview()
            make.top.equalTo(self.progressSlider.snp.bottom).offset(20)
            make.width.height.equalTo(50)
        }

        self.nextButton.snp.makeConstraints { make in
            make.leading.equalTo(self.playButton.snp.trailing).offset(20)
            make.centerY.equalTo(self.playButton)
        }

        self.timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(self.nextButton.snp.trailing).offset(20)
            make.centerY.equalTo(self.playButton)
        }

        self.danmakuInputButton.snp.makeConstraints { make in
            make.leading.equalTo(self.timeLabel.snp.trailing).offset(12)
            make.trailing.equalTo(self.playerListButton.snp.leading).offset(-12)
            make.centerY.equalTo(self.playButton)
            make.height.equalTo(36)
        }

        self.playerListButton.snp.makeConstraints { make in
            make.trailing.equalTo(-10)
            make.centerY.equalTo(self.playButton)
        }
    }
}
