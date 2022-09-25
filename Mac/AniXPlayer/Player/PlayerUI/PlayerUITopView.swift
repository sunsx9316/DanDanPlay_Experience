//
//  PlayerUITopView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/5.
//

import Cocoa
import SnapKit

class PlayerUITopView: NSView {
    
    lazy var titleLabel: TextField = {
        let label = TextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 15)
        label.textColor = .white
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
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
        containerView.addSubview(self.titleLabel)
        self.addSubview(containerView)
        
        containerView.snp.makeConstraints { make in
            make.top.equalTo(self.safeAreaLayoutGuide.snp.top)
            make.bottom.equalToSuperview()
            make.leading.equalTo(self.safeAreaLayoutGuide.snp.leading)
            make.trailing.equalTo(self.safeAreaLayoutGuide.snp.trailing)
        }
        
        self.bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalTo(15)
            make.bottom.equalTo(-15)
            make.trailing.equalTo(-10)
        }
    }
    
}
