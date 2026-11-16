//
//  Button.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/12.
//

import Cocoa

class Button: NSButton {
    
    static func custom() -> Button {
        let button = Button()
        button.bezelStyle = .texturedSquare
        button.isBordered = false
        return button
    }
    
}

/// 播放器底部控制条上的紧凑按钮。
///
/// 控制条叠在视频画面上，背景是黑色半透明。默认 `NSButton` 使用系统
/// bezel 和 `controlTextColor`，在浅色外观下文字是深色的，叠到深色视频/图片上
/// 几乎不可见。这里统一使用白色文字/图标、无边框，并在悬停时绘制半透明白色胶囊。
final class PlayerControlBarButton: Button {

    enum Style {
        case text
        case icon
    }

    private enum Metrics {
        static let fontSize: CGFloat = 12
        static let controlHeight: CGFloat = 26
        static let textHorizontalPadding: CGFloat = 9
        static let minimumTextWidth: CGFloat = 44
        static let iconHorizontalPadding: CGFloat = 5
        static let minimumIconWidth: CGFloat = 28
    }

    private let style: Style
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovering = false
    private var isPressing = false

    /// 文字按钮（选集 / 弹幕设置 / 视频设置等）。
    init(title: String) {
        self.style = .text
        super.init(frame: .zero)
        self.configure(title: title, image: nil, accessibilityLabel: title, toolTip: title)
    }

    /// 图标按钮（截图等）。
    init(image: NSImage?, accessibilityLabel: String, toolTip: String? = nil) {
        self.style = .icon
        super.init(frame: .zero)
        self.configure(
            title: "",
            image: image,
            accessibilityLabel: accessibilityLabel,
            toolTip: toolTip ?? accessibilityLabel
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let baseSize = super.intrinsicContentSize
        let baseWidth = max(baseSize.width, 0)

        let width: CGFloat
        switch self.style {
        case .text:
            width = max(Metrics.minimumTextWidth, baseWidth + Metrics.textHorizontalPadding * 2)
        case .icon:
            width = max(Metrics.minimumIconWidth, baseWidth + Metrics.iconHorizontalPadding * 2)
        }

        return NSSize(width: ceil(width), height: Metrics.controlHeight)
    }

    override func layout() {
        super.layout()
        self.layer?.cornerRadius = self.bounds.height / 2
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea = self.hoverTrackingArea {
            self.removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
        self.hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        self.isHovering = true
        self.updateBackground()
    }

    override func mouseExited(with event: NSEvent) {
        self.isHovering = false
        self.isPressing = false
        self.updateBackground()
    }

    override func mouseDown(with event: NSEvent) {
        self.isPressing = true
        self.updateBackground()
        super.mouseDown(with: event)
        self.isPressing = false
        self.updateBackground()
    }

    // MARK: - Private

    private func configure(title: String, image: NSImage?, accessibilityLabel: String, toolTip: String) {
        self.bezelStyle = .inline
        self.isBordered = false
        self.focusRingType = .none
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        self.contentTintColor = .white
        self.imageScaling = .scaleProportionallyDown
        self.setContentHuggingPriority(.required, for: .horizontal)
        self.setContentCompressionResistancePriority(.required, for: .horizontal)

        switch self.style {
        case .text:
            self.alignment = .center
            self.imagePosition = .noImage
            self.title = title
            self.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: Metrics.fontSize, weight: .semibold),
                    .foregroundColor: NSColor.white
                ]
            )
        case .icon:
            self.title = ""
            self.imagePosition = .imageOnly
            self.image = image
        }

        self.toolTip = toolTip
        self.setAccessibilityLabel(accessibilityLabel)
        self.updateBackground()
    }

    private func updateBackground() {
        let color: NSColor
        if self.isPressing {
            color = NSColor(white: 1, alpha: 0.26)
        } else if self.isHovering {
            color = NSColor(white: 1, alpha: 0.16)
        } else {
            color = .clear
        }

        self.layer?.backgroundColor = color.cgColor
        self.layer?.cornerRadius = self.bounds.height / 2
    }
}
