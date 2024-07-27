//
//  GotoLastWatchPointView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/7.
//

import UIKit
import SnapKit

class GotoLastWatchPointView: UIView {

    private lazy var timeLabel: Label = {
        let label = Label()
        label.textColor = .white
        return label
    }()
    
    private lazy var gotoButton: Button = {
        let button = Button()
        button.layer.cornerRadius = 3
        button.layer.masksToBounds = true
        button.titleLabel?.font = .ddp_normal
        button.addTarget(self, action: #selector(onTouchGotoButton), for: .touchUpInside)
        button.setTitle(NSLocalizedString("跳转", comment: ""), for: .normal)
        button.backgroundColor = .darkGray
        button.contentSizeEdge = .init(width: 30, height: 0)
        return button
    }()
    
    private var dismissTimer: Timer?
    
    var timeString: String? {
        didSet {
            self.timeLabel.text = self.timeString
        }
    }
    
    var didClickGotoButton: (() -> Void)?
    
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        self.layer.cornerRadius = 5
        self.layer.masksToBounds = true
        
        self.addSubview(self.timeLabel)
        self.addSubview(self.gotoButton)
        
        self.timeLabel.snp.makeConstraints { make in
            make.top.leading.equalTo(10)
            make.bottom.equalTo(-10)
        }
        
        self.gotoButton.snp.makeConstraints { make in
            make.trailing.bottom.equalTo(-10)
            make.leading.equalTo(self.timeLabel.snp.trailing).offset(10)
            make.top.equalTo(10)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(from view: UIView) {
        view.addSubview(self)
        
        self.snp.makeConstraints { make in
            make.trailing.equalTo(view.snp.leading)
            make.bottom.equalToSuperview().offset(-150)
        }
        
        self.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
            self.transform = .init(translationX: self.frame.width + self.safeAreaInsets.left, y: 0)
        } completion: { _ in
            self.dismissTimer = .scheduledTimer(withTimeInterval: 5, block: { [weak self] _ in
                guard let self = self else { return }
                
                self.dismiss()
            }, repeats: false)
        }
    }
    
    func dismiss() {
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
            self.transform = .identity
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
    
    @objc private func onTouchGotoButton() {
        self.didClickGotoButton?()
        self.dismiss()
    }

}
