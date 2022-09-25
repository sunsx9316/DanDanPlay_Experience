//
//  TimeTipsView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/16.
//

import Cocoa
import SnapKit

class TimeTipsView: BaseView {
    
    lazy var timeLabel: TextField = {
        var timeLabel = TextField(labelWithString: "")
        timeLabel.alignment = .center
        return timeLabel
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    func show(from view: NSView) {
        view.addSubview(self)
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().alphaValue = 1
        }
    }
    
    func dismiss() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().alphaValue = 0
        } completionHandler: {
            self.removeFromSuperview()
        }

    }
    
    
    private func setupInit() {
        self.bgColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        self.layer?.cornerRadius = 6
        self.layer?.masksToBounds = true
        self.addSubview(self.timeLabel)
        self.alphaValue = 0
        self.timeLabel.snp.makeConstraints { make in
            make.edges.equalTo(NSEdgeInsetsMake(10, 10, 10, 10))
        }
    }
    
}
