//
//  TimeTipsView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/16.
//

import Cocoa
import SnapKit

class TimeTipsView: BaseView {
    
    lazy var timeLabel: Label = {
        var timeLabel = Label(labelWithString: "")
        timeLabel.alignment = .center
        return timeLabel
    }()

    private lazy var imgView: ImageView = {
        let imgView = ImageView()
        imgView.setScaling(.aspectFit)
        imgView.isHidden = true
        return imgView
    }()

    private var imgHeightConstraint: Constraint?

    private(set) var hasThumbnail = false

    /// 期望尺寸：有缩略图时更大（8 + 图高 + 4 + 18 + 8）
    var desiredSize: CGSize {
        return self.hasThumbnail ? CGSize(width: 176, height: 128) : CGSize(width: 100, height: 38)
    }

    /// 设置缩略图（nil 表示无/加载失败）
    func setThumbnail(_ image: ANXImage?) {
        self.hasThumbnail = image != nil
        self.imgView.image = image
        self.imgView.isHidden = image == nil
        self.imgHeightConstraint?.update(offset: image == nil ? 0 : 90)
    }
    
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
        self.addSubview(self.imgView)
        self.addSubview(self.timeLabel)
        self.alphaValue = 0

        self.imgView.snp.makeConstraints { make in
            make.top.leading.equalTo(8)
            make.trailing.equalTo(-8)
            self.imgHeightConstraint = make.height.equalTo(0).constraint
        }

        self.timeLabel.snp.makeConstraints { make in
            make.top.equalTo(self.imgView.snp.bottom).offset(4)
            make.leading.trailing.equalTo(self.imgView)
            make.height.equalTo(18)
            make.bottom.equalTo(-8)
        }
    }
    
}
