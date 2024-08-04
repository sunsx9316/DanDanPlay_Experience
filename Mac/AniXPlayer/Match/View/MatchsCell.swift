//
//  MatchsCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa
import SnapKit

class MatchsCell: BaseView {

    private lazy var titleLabel: TextField = {
        let title = TextField(labelWithString: "")
        return title
    }()
    
    private lazy var typeLabel: TextField = {
        let title = TextField(labelWithString: "")
        title.backgroundColor = .mainColor
        title.drawsBackground = true
        title.wantsLayer = true
        title.layer?.cornerRadius = 3
        title.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        title.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return title
    }()
    
    var model: MediaMatchItem? {
        didSet {
            
            let typeDesc = self.model?.typeDesc ?? ""
            let title = self.model?.title ?? ""
            
            self.typeLabel.stringValue = typeDesc
            self.titleLabel.stringValue = title
            self.titleLabel.toolTip = title
            
            self.typeLabel.isHidden = typeDesc.isEmpty
            self.titleLabel.isHidden = title.isEmpty
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    private func setupInit() {
        self.addSubview(self.titleLabel)
        self.addSubview(self.typeLabel)
        self.typeLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(3)
        }
        
        self.titleLabel.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview()
            make.leading.equalTo(self.typeLabel.snp.trailing).offset(5)
            make.top.equalTo(3)
        }
    }
    
}
