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
        label.font = .ddp_large
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
        
        self.bgColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.6)
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
        self.animator().alphaValue = 0
        
        view.addSubview(self)
        
        self.snp.makeConstraints { make in
            make.leading.equalTo(view.snp.leading)
            make.bottom.equalToSuperview().offset(-150)
        }
        
        NSAnimationContext.runAnimationGroup { ctx in
            self.animator().alphaValue = 1
        } completionHandler: {
            self.dismissTimer = .scheduledTimer(withTimeInterval: 5, block: { [weak self] _ in
                guard let self = self else { return }
                
                self.dismiss()
            }, repeats: false)
        }
    }
    
    func dismiss() {
        NSAnimationContext.runAnimationGroup { ctx in
            self.animator().alphaValue = 0
        } completionHandler: {
            self.removeFromSuperview()
        }
    }
    
    @objc private func onTouchGotoButton() {
        self.didClickGotoButton?()
        self.dismiss()
    }

}
