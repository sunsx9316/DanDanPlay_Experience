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

    private enum Metrics {
        /// 预览图片尺寸（16:9）
        static let imageSize = CGSize(width: 160, height: 90)
        static let horizontalMargin: CGFloat = 10
        static let contentSpacing: CGFloat = 6
        static let actionButtonHeight: CGFloat = 26
        /// 自动消失时间；要留出时间让用户点到「保存动图」
        static let autoDismissInterval: TimeInterval = 10
        /// 悬停/聚焦时轮询是否仍然需要暂停，避免卡片在按钮下方消失
        static let pauseCheckInterval: TimeInterval = 0.5
    }

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

    /// 截图保存成功后才显示的动图入口；点击后进入现有 GIF 导出流程。
    private lazy var saveGIFButton: NSButton = {
        let title = NSLocalizedString("保存动图", comment: "")
        let button = NSButton(title: title, target: self, action: #selector(onClickSaveGIF))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11.5, weight: .medium)
        button.toolTip = NSLocalizedString("从当前时间导出动图", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.Player.snapshotSaveGIF)
        button.isHidden = true
        return button
    }()

    private lazy var contentStack: NSStackView = {
        let stackView = NSStackView(views: [self.imgView, self.tipLabel, self.saveGIFButton])
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = Metrics.contentSpacing
        stackView.detachesHiddenViews = true
        return stackView
    }()

    private var dismissTimer: Timer?

    private var isDismissing = false

    /// 最近一次计时器触发时是否因为悬停/聚焦而暂停
    private var isPausedForInteraction = false

    private var trackingArea: NSTrackingArea?

    /// 点击预览（用于在访达中定位文件）
    var didClickReveal: (() -> Void)?

    /// 点击「保存动图」；由播放器接到现有 exportGIF() 上。
    var onSaveGIF: (() -> Void)?

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
        self.isPausedForInteraction = false
        self.onSaveGIF = nil
        self.setSaveGIFVisible(false)

        if self.superview !== view {
            self.removeFromSuperview()
            self.alphaValue = 0
            view.addSubview(self)

            self.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-20)
                make.centerY.equalToSuperview()
                make.width.equalTo(Metrics.imageSize.width + Metrics.horizontalMargin * 2)
            }
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().alphaValue = 1
        }

        self.restartDismissTimer()
    }

    /// 截图保存成功后才允许展示「保存动图」；失败/权限失败时保持隐藏。
    func setSaveGIFVisible(_ visible: Bool) {
        let shouldHide = !visible
        guard self.saveGIFButton.isHidden != shouldHide else { return }
        self.saveGIFButton.isHidden = shouldHide
        self.window?.invalidateCursorRects(for: self)

        if !shouldHide {
            // 从按钮出现时重新计时，避免保存耗时挤占点击时间。
            self.restartDismissTimer()
        }
    }

    func dismiss() {
        self.dismissTimer?.invalidate()
        self.dismissTimer = nil
        self.isPausedForInteraction = false
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
        super.resetCursorRects()
        // 只有图片和提示文字可点击定位；按钮自己处理鼠标，避免点击冲突。
        self.addCursorRect(self.convert(self.imgView.bounds, from: self.imgView), cursor: .pointingHand)
        self.addCursorRect(self.convert(self.tipLabel.bounds, from: self.tipLabel), cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        self.restartDismissTimer()
    }

    override func mouseExited(with event: NSEvent) {
        self.restartDismissTimer()
    }

    private var isPointerInsideView: Bool {
        guard let window = self.window else { return false }
        let point = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        return self.bounds.contains(point)
    }

    private var isActionButtonFocused: Bool {
        guard let firstResponder = self.window?.firstResponder else { return false }
        return firstResponder === self.saveGIFButton
    }

    /// 悬停或聚焦按钮时暂停自动消失，保证按钮始终来得及点击。
    private var shouldPauseAutoDismiss: Bool {
        return self.isPointerInsideView || self.isActionButtonFocused
    }

    private func restartDismissTimer() {
        self.dismissTimer?.invalidate()
        self.dismissTimer = nil
        self.isPausedForInteraction = false

        let interval = self.shouldPauseAutoDismiss ? Metrics.pauseCheckInterval : Metrics.autoDismissInterval
        self.scheduleDismissTimer(after: interval)
    }

    private func scheduleDismissTimer(after interval: TimeInterval) {
        self.dismissTimer?.invalidate()
        self.dismissTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.dismissTimerFired()
        }
    }

    private func dismissTimerFired() {
        self.dismissTimer = nil

        if self.shouldPauseAutoDismiss {
            self.isPausedForInteraction = true
            self.scheduleDismissTimer(after: Metrics.pauseCheckInterval)
            return
        }

        if self.isPausedForInteraction {
            // 用户刚把鼠标/焦点移开，再给一轮完整展示时间。
            self.isPausedForInteraction = false
            self.scheduleDismissTimer(after: Metrics.autoDismissInterval)
            return
        }

        self.dismiss()
    }

    @objc private func onClickSaveGIF() {
        let action = self.onSaveGIF
        self.dismiss()
        action?()
    }

    @objc private func onClickReveal() {
        self.didClickReveal?()
        self.dismiss()
    }

    private func setupInit() {
        self.bgColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        self.layer?.cornerRadius = 6
        self.layer?.masksToBounds = true

        let revealGesture = NSClickGestureRecognizer(target: self, action: #selector(onClickReveal))
        self.imgView.addGestureRecognizer(revealGesture)
        self.tipLabel.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(onClickReveal)))

        self.addSubview(self.contentStack)

        self.contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Metrics.horizontalMargin)
            make.leading.equalToSuperview().offset(Metrics.horizontalMargin)
            make.trailing.equalToSuperview().offset(-Metrics.horizontalMargin)
            make.bottom.equalToSuperview().offset(-Metrics.horizontalMargin)
        }

        self.imgView.snp.makeConstraints { make in
            make.width.equalTo(Metrics.imageSize.width)
            make.height.equalTo(Metrics.imageSize.height)
        }

        self.tipLabel.snp.makeConstraints { make in
            make.width.equalTo(Metrics.imageSize.width)
        }

        self.saveGIFButton.snp.makeConstraints { make in
            make.width.equalTo(Metrics.imageSize.width)
            make.height.equalTo(Metrics.actionButtonHeight)
        }
    }
}
