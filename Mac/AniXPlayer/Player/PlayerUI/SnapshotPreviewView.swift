//
//  SnapshotPreviewView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/5/4.
//

import Cocoa
import SnapKit

/// 截图预览视图
/// 截图成功后从播放器右侧滑出，短暂展示后自动消失
class SnapshotPreviewView: BaseView {

    /// 预览图片尺寸（16:9）
    private static let imageSize = CGSize(width: 160, height: 90)

    private lazy var imgView: ImageView = {
        let imgView = ImageView()
        imgView.setScaling(.aspectFill)
        imgView.layer?.cornerRadius = 4
        imgView.layer?.masksToBounds = true
        return imgView
    }()

    private lazy var tipLabel: Label = {
        let label = Label(labelWithString: "")
        label.textColor = .white
        label.font = .ddp_small
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.isSelectable = false
        return label
    }()

    private var dismissTimer: Timer?

    private var isDismissing = false

    /// 点击预览（用于在访达中定位文件）
    var didClickReveal: (() -> Void)?

    /// 底部提示文案，展示保存状态
    var tipText: String? {
        didSet {
            self.tipLabel.text = self.tipText ?? ""
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

    /// 展示预览
    /// - Parameters:
    ///   - image: 截图
    ///   - view: 父视图（一般传播放器根视图）
    func show(image: NSImage, from view: NSView) {
        self.imgView.image = image
        self.dismissTimer?.invalidate()
        self.isDismissing = false

        if self.superview !== view {
            self.removeFromSuperview()
            self.alphaValue = 0
            view.addSubview(self)

            self.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-20)
                make.centerY.equalToSuperview()
                make.width.equalTo(Self.imageSize.width + 20)
            }
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().alphaValue = 1
        }

        self.dismissTimer = .scheduledTimer(withTimeInterval: 3, block: { [weak self] _ in
            self?.dismiss()
        }, repeats: false)
    }

    func dismiss() {
        self.dismissTimer?.invalidate()
        self.dismissTimer = nil
        self.isDismissing = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().alphaValue = 0
        } completionHandler: {
            guard self.isDismissing else { return }
            self.removeFromSuperview()
        }
    }

    override func resetCursorRects() {
        self.addCursorRect(self.bounds, cursor: .pointingHand)
    }

    @objc private func onClick() {
        self.didClickReveal?()
        self.dismiss()
    }

    private func setupInit() {
        self.bgColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        self.layer?.cornerRadius = 6
        self.layer?.masksToBounds = true

        self.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(onClick)))

        self.addSubview(self.imgView)
        self.addSubview(self.tipLabel)

        self.imgView.snp.makeConstraints { make in
            make.top.leading.equalTo(10)
            make.trailing.equalTo(-10)
            make.height.equalTo(Self.imageSize.height)
        }

        self.tipLabel.snp.makeConstraints { make in
            make.top.equalTo(self.imgView.snp.bottom).offset(6)
            make.leading.trailing.equalTo(self.imgView)
            make.bottom.equalTo(-10)
        }
    }
}
