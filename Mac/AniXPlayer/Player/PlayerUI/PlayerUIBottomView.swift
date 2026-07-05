//
//  PlayerUIBottomView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/6.
//

import Cocoa
import SnapKit

// MARK: - PlayerUIBottomView

class PlayerUIBottomView: BaseView {

    lazy var progressSlider: PlayerSlider = {
        let slider = PlayerSlider()
        slider.progressHeight = 8
        return slider
    }()

    lazy var playButton: Button = {
        let button = Button.custom()
        button.setButtonType(.switch)
        button.imagePosition = .imageOnly
        button.image = .init(named: "Player/play")
        button.alternateImage = .init(named: "Player/pause")
        return button
    }()
    
    lazy var stopButton: Button = {
        let button = Button.custom()
        button.imagePosition = .imageOnly
        button.image = NSImage(named: "Player/stop")
        return button
    }()

    lazy var nextButton: Button = {
        let button = Button.custom()
        button.imagePosition = .imageOnly
        button.image = NSImage(named: "Player/next")
        return button
    }()
    
    lazy var timeLabel: Label = {
        let label = Label(labelWithString: "")
        label.textColor = .white
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.alignment = .center
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    lazy var playerListButton: Button = {
        let button = Button(title: NSLocalizedString("选集", comment: ""), target: nil, action: nil)
        return button
    }()
    
    lazy var danmakuSettingButton: Button = {
        let button = Button(title: NSLocalizedString("弹幕设置", comment: ""), target: nil, action: nil)
        return button
    }()

    lazy var danmakuTextField: TextField = {
        let tf = TextField()
        tf.centersVertically = true
        tf.font = .systemFont(ofSize: 12)
        tf.textColor = .white
        tf.drawsBackground = true
        tf.backgroundColor = NSColor(white: 0, alpha: 0.3)
        tf.placeholderString = NSLocalizedString("发个弹幕吧", comment: "")
        tf.isBordered = false
        tf.wantsLayer = true
        tf.layer?.cornerRadius = 4
        tf.layer?.masksToBounds = true
        return tf
    }()

    lazy var danmakuConfigButton: Button = {
        let button = Button(title: NSLocalizedString("弹幕配置", comment: ""), target: nil, action: nil)
        button.font = .systemFont(ofSize: 12)
        return button
    }()

    lazy var mediaSettingButton: Button = {
        let button = Button(title: NSLocalizedString("视频设置", comment: ""), target: nil, action: nil)
        return button
    }()
    
    private lazy var bgView: BaseView = {
        let bgView = BaseView()
        bgView.bgColor = NSColor(white: 0, alpha: 0.4)
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
        let containerView = BaseView()
        containerView.addSubview(self.progressSlider)
        containerView.addSubview(self.playButton)
        containerView.addSubview(self.stopButton)
        containerView.addSubview(self.nextButton)
        containerView.addSubview(self.timeLabel)
        containerView.addSubview(self.playerListButton)
        containerView.addSubview(self.mediaSettingButton)
        containerView.addSubview(self.danmakuTextField)
        containerView.addSubview(self.danmakuConfigButton)
        containerView.addSubview(self.danmakuSettingButton)
        
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
            make.top.equalTo(2)
            make.leading.equalTo(0)
            make.trailing.equalTo(0)
            make.height.equalTo(10)
        }
        
        self.playButton.snp.makeConstraints { make in
            make.leading.equalTo(self.progressSlider).offset(10)
            make.bottom.equalToSuperview().offset(-5)
            make.top.equalTo(self.progressSlider.snp.bottom).offset(5)
            make.width.height.equalTo(50)
        }
        
        self.stopButton.snp.makeConstraints { make in
            make.leading.equalTo(self.playButton.snp.trailing).offset(20)
            make.centerY.equalTo(self.playButton)
        }

        self.nextButton.snp.makeConstraints { make in
            make.leading.equalTo(self.stopButton.snp.trailing).offset(20)
            make.centerY.equalTo(self.playButton)
        }

        self.timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(self.nextButton.snp.trailing).offset(20)
            make.centerY.equalTo(self.playButton)
            make.width.greaterThanOrEqualTo(100)
        }

        self.danmakuTextField.snp.makeConstraints { make in
            make.centerY.equalTo(self.playButton)
            make.leading.equalTo(self.timeLabel.snp.trailing).offset(10)
            make.width.equalTo(130)
            make.height.equalTo(24)
        }

        self.danmakuConfigButton.snp.makeConstraints { make in
            make.centerY.equalTo(self.playButton)
            make.leading.equalTo(self.danmakuTextField.snp.trailing).offset(6)
        }

        self.playerListButton.snp.makeConstraints { make in
            make.centerY.equalTo(self.playButton)
            make.leading.greaterThanOrEqualTo(self.danmakuConfigButton.snp.trailing).offset(15)
        }

        self.mediaSettingButton.snp.makeConstraints { make in
            make.centerY.equalTo(self.playButton)
            make.leading.equalTo(self.playerListButton.snp.trailing).offset(10)
        }

        self.danmakuSettingButton.snp.makeConstraints { make in
            make.trailing.equalTo(-10)
            make.centerY.equalTo(self.playButton)
            make.leading.equalTo(self.mediaSettingButton.snp.trailing).offset(10)
        }
        
    }
}
