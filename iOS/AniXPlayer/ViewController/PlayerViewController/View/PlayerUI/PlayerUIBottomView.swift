//
//  PlayerUIBottomView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/6.
//

import UIKit
import SnapKit

class PlayerUIBottomView: UIView {

    lazy var progressSlider: UISlider = {
        let slider = UISlider()
        slider.tintColor = UIColor.mainColor
        slider.setThumbImage(UIImage(color: UIColor.white, size: CGSize(width: 16, height: 10))?.byRoundCornerRadius(2), for: .normal)
        return slider
    }()

    lazy var playButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "Player/player_play"), for: .normal)
        button.setImage(UIImage(named: "Player/player_pause"), for: .selected)
        button.adjustsImageWhenHighlighted = true
        button.adjustsImageWhenDisabled = true
        return button
    }()
    
    lazy var nextButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "Player/player_next"), for: .normal)
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
        button.setImage(UIImage(named: "Player/player_list"), for: .normal)
        button.adjustsImageWhenHighlighted = true
        button.adjustsImageWhenDisabled = true
        return button
    }()
    
    private lazy var bgImgView: UIImageView = {
        let bgImgView = UIImageView(image: UIImage(named: "Player/comment_gradual_gray"))
        return bgImgView
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
        self.addSubview(self.bgImgView)
        let containerView = UIView()
        containerView.addSubview(self.progressSlider)
        containerView.addSubview(self.playButton)
        containerView.addSubview(self.nextButton)
        containerView.addSubview(self.timeLabel)
        containerView.addSubview(self.playerListButton)
        self.addSubview(containerView)
        
        self.bgImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.leading.equalTo(self.safeAreaLayoutGuide.snp.leading)
            make.trailing.equalTo(self.safeAreaLayoutGuide.snp.trailing)
            make.bottom.equalTo(self.safeAreaLayoutGuide.snp.bottom)
            make.top.equalToSuperview()
        }
        
        self.progressSlider.snp.makeConstraints { make in
            make.top.leading.equalTo(10)
            make.trailing.equalTo(-10)
        }
        
        self.playButton.snp.makeConstraints { make in
            make.leading.equalTo(self.progressSlider)
            make.bottom.equalToSuperview()
            make.top.equalTo(self.progressSlider.snp.bottom).offset(20)
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
