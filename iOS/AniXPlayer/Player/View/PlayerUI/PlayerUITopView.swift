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
        backButton.setImage(UIImage(named: "Public/go_back")?.byTintColor(.white), for: .normal)
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
        button.setTitle(NSLocalizedString("设置", comment: ""), for: .normal)
        button.hitTestSlop = .init(top: -10, left: -10, bottom: -10, right: -10)
        button.adjustsImageWhenHighlighted = true
        button.adjustsImageWhenDisabled = true
        return button
    }()
    
    lazy var resetScaleButton: Button = {
        var button = Button(type: .custom)
        button.layer.cornerRadius = 4
        button.layer.masksToBounds = true
        button.setTitle(NSLocalizedString("恢复视频大小", comment: ""), for: .normal)
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
        
        self.preservesSuperviewLayoutMargins = true
        
        self.addSubview(self.bgView)
        let containerView = UIView()
        containerView.addSubview(self.titleLabel)
        containerView.addSubview(self.backButton)
        
        let rightStackView = UIStackView()
        rightStackView.axis = .horizontal
        rightStackView.spacing = PlayerLayoutMetrics.topBarControlSpacing
        rightStackView.addArrangedSubview(self.resetScaleButton)
        rightStackView.addArrangedSubview(self.settingButton)
        
        containerView.addSubview(rightStackView)
        
        self.addSubview(containerView)
        
        containerView.snp.makeConstraints { make in
            make.top.equalTo(self.safeAreaLayoutGuide.snp.top)
            make.bottom.equalToSuperview()
            make.leading.trailing.equalTo(self.safeAreaLayoutGuide)
        }
        
        self.bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.backButton.snp.makeConstraints { make in
            make.top.equalTo(PlayerLayoutMetrics.topBarVerticalPadding)
            make.bottom.equalTo(-PlayerLayoutMetrics.topBarVerticalPadding)
            make.leading.equalToSuperview()
            make.width.height.equalTo(PlayerLayoutMetrics.backButtonSize)
        }
        
        self.titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(self.backButton.snp.trailing).offset(5)
            make.centerY.equalTo(self.backButton)
            make.top.bottom.equalToSuperview()
        }
        
        rightStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.width.greaterThanOrEqualTo(PlayerLayoutMetrics.topBarControlMinWidth)
            make.centerY.equalTo(self.backButton)
            make.leading.equalTo(self.titleLabel.snp.trailing).offset(5)
        }
        
        self.settingButton.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(PlayerLayoutMetrics.topBarControlMinWidth)
        }
    }
    
}
