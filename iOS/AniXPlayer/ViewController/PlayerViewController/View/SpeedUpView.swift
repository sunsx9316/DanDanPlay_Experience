//
//  SpeedUpView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/10/24.
//

import UIKit

class SpeedUpView: UIView {

    lazy var titleLabel: Label = {
        let label = Label()
        label.textColor = .white
        return label
    }()
    
    private lazy var arrowLabel1: Label = {
        let label = Label()
        label.text = NSLocalizedString("▶︎", comment: "")
        label.textColor = .mainColor
        return label
    }()
    
    private lazy var arrowLabel2: Label = {
        let label = Label()
        label.text = NSLocalizedString("▶︎", comment: "")
        label.textColor = .mainColor
        return label
    }()
    
    private lazy var arrowLabel3: Label = {
        let label = Label()
        label.text = NSLocalizedString("▶︎", comment: "")
        label.textColor = .mainColor
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addSubview(self.titleLabel)
        self.addSubview(self.arrowLabel1)
        self.addSubview(self.arrowLabel2)
        self.addSubview(self.arrowLabel3)
        
        self.titleLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        
        self.arrowLabel1.snp.makeConstraints { make in
            make.leading.equalTo(self.titleLabel.snp.trailing).offset(5)
            make.centerY.equalTo(self.titleLabel)
        }
        
        self.arrowLabel2.snp.makeConstraints { make in
            make.leading.equalTo(self.arrowLabel1.snp.trailing)
            make.centerY.equalTo(self.titleLabel)
        }
        
        self.arrowLabel3.snp.makeConstraints { make in
            make.leading.equalTo(self.arrowLabel2.snp.trailing)
            make.centerY.equalTo(self.titleLabel)
            make.trailing.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func startAnimate() {
        self.arrowLabel1.alpha = 0
        self.arrowLabel2.alpha = 0
        self.arrowLabel3.alpha = 0
        
        UIView.animateKeyframes(withDuration: 1.2, delay: 0, options: .repeat) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2) {
                self.arrowLabel1.alpha = 1
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.166, relativeDuration: 0.2) {
                self.arrowLabel2.alpha = 1
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.332, relativeDuration: 0.2) {
                self.arrowLabel3.alpha = 1
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.498, relativeDuration: 0.2) {
                self.arrowLabel1.alpha = 0
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.664, relativeDuration: 0.2) {
                self.arrowLabel2.alpha = 0
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.83, relativeDuration: 0.2) {
                self.arrowLabel3.alpha = 0
            }
        } completion: { _ in
            
        }

    }
    
}
