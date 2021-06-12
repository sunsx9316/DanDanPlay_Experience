//
//  PlayerUITopView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/5.
//

import UIKit
import SnapKit

class PlayerUITopView: UIView {
    
    lazy var backButton: UIButton = {
        let backButton = UIButton(type: .custom)
        backButton.setImage(UIImage(named: "Player/comment_back_item"), for: .normal)
        backButton.adjustsImageWhenHighlighted = true
        backButton.adjustsImageWhenDisabled = true
        return backButton
    }()
    
    lazy var titleLabel: AutoScrollLabel = {
        let label = AutoScrollLabel()
        label.isUserInteractionEnabled = false
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    lazy var settingButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "Player/player_more"), for: .normal)
        button.hitTestSlop = .init(top: -10, left: -10, bottom: -10, right: -10)
        button.adjustsImageWhenHighlighted = true
        button.adjustsImageWhenDisabled = true
        return button
    }()
    
    private lazy var bgImgView: UIImageView = {
        let bgImgView = UIImageView(image: UIImage(named: "Player/comment_gradual_gray_b2w"))
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
        containerView.addSubview(self.titleLabel)
        containerView.addSubview(self.settingButton)
        containerView.addSubview(self.backButton)
        self.addSubview(containerView)
        
        containerView.snp.makeConstraints { make in
            make.top.equalTo(self.safeAreaLayoutGuide.snp.top)
            make.bottom.equalToSuperview()
            make.leading.equalTo(self.safeAreaLayoutGuide.snp.leading)
            make.trailing.equalTo(self.safeAreaLayoutGuide.snp.trailing)
        }
        
        self.bgImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.backButton.snp.makeConstraints { make in
            make.top.equalTo(20)
            make.bottom.equalTo(-20)
            make.leading.equalToSuperview()
            make.width.height.equalTo(30)
        }
        
        self.titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(self.backButton.snp.trailing).offset(5)
            make.centerY.equalTo(self.backButton)
            make.top.bottom.equalToSuperview()
        }
        
        self.settingButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.width.height.equalTo(30)
            make.centerY.equalTo(self.backButton)
            make.leading.equalTo(self.titleLabel.snp.trailing).offset(5)
        }
    }
    
}
