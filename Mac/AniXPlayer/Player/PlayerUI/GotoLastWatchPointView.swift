//
//  GotoLastWatchPointView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/7.
//

import Cocoa
import SnapKit

class GotoLastWatchPointView: BaseView {

    private lazy var timeLabel: TextField = {
        let label = TextField(labelWithString: "")
        label.textColor = .white
        return label
    }()
    
    private lazy var gotoButton: NSButton = {
        let button = NSButton(title: NSLocalizedString("跳转", comment: ""), target: self, action: #selector(onTouchGotoButton))
        button.layer?.cornerRadius = 3
        button.layer?.masksToBounds = true
        button.font = .ddp_normal
        return button
    }()
    
    private var dismissTimer: Timer?
    
    var timeString: String? {
        didSet {
            self.timeLabel.stringValue = self.timeString ?? ""
        }
    }
    
    var didClickGotoButton: (() -> Void)?
    
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.bgColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        self.layer?.cornerRadius = 5
        self.layer?.masksToBounds = true
        
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
    
    func show(from view: NSView) {
        view.addSubview(self)
        
        self.snp.makeConstraints { make in
            make.trailing.equalTo(view.snp.leading)
            make.bottom.equalToSuperview().offset(-150)
        }
        
        self.layer?.layoutIfNeeded()
        
        NSAnimationContext.runAnimationGroup { ctx in
            self.animator().layer?.transform = CATransform3DMakeAffineTransform(.init(translationX: self.frame.width, y: 0))
        } completionHandler: {
            self.dismissTimer = .scheduledTimer(withTimeInterval: 5, block: { [weak self] _ in
                guard let self = self else { return }
                
                self.dismiss()
            }, repeats: false)
        }
    }
    
    func dismiss() {
        NSAnimationContext.runAnimationGroup { ctx in
            self.animator().layer?.transform = CATransform3DIdentity
        } completionHandler: {
            self.removeFromSuperview()
        }
    }
    
    @objc private func onTouchGotoButton() {
        self.didClickGotoButton?()
        self.dismiss()
    }

}
