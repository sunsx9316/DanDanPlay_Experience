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
    
    lazy var nextButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "Player/play_next"), for: .normal)
        button.adjustsImageWhenHighlighted = true
        button.adjustsImageWhenDisabled = true
        return button
    }()
    
    lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    lazy var playerListButton: UIButton = {
        let button = UIButton(type: .custom)
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
        
        self.playerListButton.snp.makeConstraints { make in
            make.trailing.equalTo(-10)
            make.centerY.equalTo(self.playButton)
            make.leading.greaterThanOrEqualTo(self.timeLabel.snp.trailing)
        }
        
    }
}
