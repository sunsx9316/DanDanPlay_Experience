//
//  PlayerUIBottomView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/6.
//

import Cocoa
import SnapKit

// MARK: - PlayerUIBottomView

class PlayerUIBottomView: BaseView {

    /// 宽度不足时被折叠到「更多」菜单里的操作。
    /// 「选集」「弹幕配置」「截图」保持在控制条上；右侧最后两个文字入口进菜单。
    enum OverflowAction: String {
        case mediaSetting
        case danmakuSetting
    }

    /// 「更多」菜单选中回调；由 PlayerUIView 转成现有 delegate 回调。
    var onOverflowAction: ((OverflowAction) -> Void)?

    lazy var progressSlider: PlayerSlider = {
        let slider = PlayerSlider()
        slider.progressHeight = 8
        return slider
    }()

    lazy var playButton: Button = {
        let button = Button.custom()
        button.setButtonType(.switch)
        button.imagePosition = .imageOnly
        button.image = .init(named: "Player/play")
        button.alternateImage = .init(named: "Player/pause")
        button.contentTintColor = .white
        return button
    }()
    
    lazy var stopButton: Button = {
        let button = Button.custom()
        button.imagePosition = .imageOnly
        button.image = NSImage(named: "Player/stop")
        button.contentTintColor = .white
        return button
    }()

    lazy var nextButton: Button = {
        let button = Button.custom()
        button.imagePosition = .imageOnly
        button.image = NSImage(named: "Player/next")
        button.contentTintColor = .white
        return button
    }()
    
    lazy var timeLabel: Label = {
        let label = Label(labelWithString: "")
        label.textColor = .white
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.alignment = .center
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    lazy var playerListButton: PlayerControlBarButton = {
        return PlayerControlBarButton(title: NSLocalizedString("选集", comment: ""))
    }()
    
    lazy var danmakuSettingButton: PlayerControlBarButton = {
        return PlayerControlBarButton(title: NSLocalizedString("弹幕设置", comment: ""))
    }()

    lazy var danmakuTextField: TextField = {
        let tf = TextField()
        tf.centersVertically = true
        tf.font = .systemFont(ofSize: 12)
        tf.textColor = .white
        tf.drawsBackground = true
        tf.backgroundColor = NSColor(white: 0, alpha: 0.3)
        tf.placeholderString = NSLocalizedString("发个弹幕吧", comment: "")
        tf.isBordered = false
        tf.wantsLayer = true
        tf.layer?.cornerRadius = 4
        tf.layer?.masksToBounds = true
        return tf
    }()

    lazy var danmakuConfigButton: PlayerControlBarButton = {
        return PlayerControlBarButton(title: NSLocalizedString("弹幕配置", comment: ""))
    }()

    lazy var mediaSettingButton: PlayerControlBarButton = {
        return PlayerControlBarButton(title: NSLocalizedString("视频设置", comment: ""))
    }()

    lazy var thumbnailButton: PlayerControlBarButton = {
        return PlayerControlBarButton(
            image: NSImage.safeSystemSymbol("camera"),
            accessibilityLabel: NSLocalizedString("截图", comment: "")
        )
    }()

    /// 窄窗口下折叠菜单入口。
    lazy var moreButton: PlayerControlBarButton = {
        return PlayerControlBarButton(title: NSLocalizedString("更多", comment: ""))
    }()

    private lazy var inputStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.detachesHiddenViews = true
        return stack
    }()

    private lazy var trailingStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = 2
        stack.detachesHiddenViews = true
        return stack
    }()

    private lazy var overflowMenu: NSMenu = {
        let menu = NSMenu()
        menu.autoenablesItems = true

        let mediaItem = NSMenuItem(
            title: NSLocalizedString("视频设置", comment: ""),
            action: #selector(handleOverflowMenuItem(_:)),
            keyEquivalent: ""
        )
        mediaItem.target = self
        mediaItem.representedObject = OverflowAction.mediaSetting.rawValue
        menu.addItem(mediaItem)

        let danmakuItem = NSMenuItem(
            title: NSLocalizedString("弹幕设置", comment: ""),
            action: #selector(handleOverflowMenuItem(_:)),
            keyEquivalent: ""
        )
        danmakuItem.target = self
        danmakuItem.representedObject = OverflowAction.danmakuSetting.rawValue
        menu.addItem(danmakuItem)

        return menu
    }()

    private var isCompactMode = false

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
    
    override func layout() {
        super.layout()
        self.updateCompactModeIfNeeded()
    }

    private func setupInit() {
        self.setAccessibilityIdentifier(AccessibilityID.Player.controls)
        self.progressSlider.setAccessibilityIdentifier(AccessibilityID.Player.progressSlider)
        self.playButton.setAccessibilityIdentifier(AccessibilityID.Player.playPauseButton)
        self.playButton.setAccessibilityLabel(NSLocalizedString("播放/暂停", comment: ""))
        self.stopButton.setAccessibilityIdentifier(AccessibilityID.Player.stopButton)
        self.stopButton.setAccessibilityLabel(NSLocalizedString("停止", comment: ""))
        self.nextButton.setAccessibilityIdentifier(AccessibilityID.Player.nextButton)
        self.nextButton.setAccessibilityLabel(NSLocalizedString("下一个", comment: ""))
        self.timeLabel.setAccessibilityIdentifier(AccessibilityID.Player.timeLabel)
        self.danmakuTextField.setAccessibilityIdentifier(AccessibilityID.Player.danmakuTextField)
        self.playerListButton.setAccessibilityIdentifier(AccessibilityID.Player.playerListButton)
        self.playerListButton.setAccessibilityLabel(NSLocalizedString("选集", comment: ""))
        self.playerListButton.toolTip = NSLocalizedString("选集", comment: "")
        self.mediaSettingButton.setAccessibilityIdentifier(AccessibilityID.Player.mediaSettingButton)
        self.mediaSettingButton.setAccessibilityLabel(NSLocalizedString("视频设置", comment: ""))
        self.mediaSettingButton.toolTip = NSLocalizedString("视频设置", comment: "")
        self.thumbnailButton.setAccessibilityIdentifier(AccessibilityID.Player.screenshotButton)
        self.thumbnailButton.setAccessibilityLabel(NSLocalizedString("截图", comment: ""))
        self.thumbnailButton.toolTip = NSLocalizedString("截图", comment: "")
        self.danmakuConfigButton.setAccessibilityIdentifier(AccessibilityID.Player.danmakuConfigButton)
        self.danmakuConfigButton.setAccessibilityLabel(NSLocalizedString("弹幕配置", comment: ""))
        self.danmakuConfigButton.toolTip = NSLocalizedString("弹幕配置", comment: "")
        self.danmakuSettingButton.setAccessibilityIdentifier(AccessibilityID.Player.danmakuSettingButton)
        self.danmakuSettingButton.setAccessibilityLabel(NSLocalizedString("弹幕设置", comment: ""))
        self.danmakuSettingButton.toolTip = NSLocalizedString("弹幕设置", comment: "")
        self.moreButton.setAccessibilityIdentifier(AccessibilityID.Player.moreButton)
        self.moreButton.setAccessibilityLabel(NSLocalizedString("更多", comment: ""))
        self.moreButton.toolTip = NSLocalizedString("更多", comment: "")
        self.moreButton.target = self
        self.moreButton.action = #selector(showOverflowMenu(_:))

        self.inputStack.addArrangedSubview(self.danmakuTextField)
        self.inputStack.addArrangedSubview(self.danmakuConfigButton)

        self.trailingStack.addArrangedSubview(self.playerListButton)
        self.trailingStack.addArrangedSubview(self.mediaSettingButton)
        self.trailingStack.addArrangedSubview(self.thumbnailButton)
        self.trailingStack.addArrangedSubview(self.danmakuSettingButton)
        self.trailingStack.addArrangedSubview(self.moreButton)
        self.moreButton.isHidden = true

        self.addSubview(self.bgView)
        let containerView = BaseView()
        containerView.addSubview(self.progressSlider)
        containerView.addSubview(self.playButton)
        containerView.addSubview(self.stopButton)
        containerView.addSubview(self.nextButton)
        containerView.addSubview(self.timeLabel)
        containerView.addSubview(self.inputStack)
        containerView.addSubview(self.trailingStack)
        
        self.addSubview(containerView)
        
        self.bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.leading.equalTo(self.safeAreaLayoutGuide.snp.leading)
            make.trailing.equalTo(self.safeAreaLayoutGuide.snp.trailing)
            make.bottom.equalTo(self.safeAreaLayoutGuide.snp.bottom)
            make.top.equalToSuperview()
        }
        
        self.progressSlider.snp.makeConstraints { make in
            make.top.equalTo(2)
            make.leading.equalTo(0)
            make.trailing.equalTo(0)
            make.height.equalTo(10)
        }
        
        self.playButton.snp.makeConstraints { make in
            make.leading.equalTo(self.progressSlider).offset(10)
            make.bottom.equalToSuperview().offset(-5)
            make.top.equalTo(self.progressSlider.snp.bottom).offset(5)
            make.width.height.equalTo(50)
        }
        
        self.stopButton.snp.makeConstraints { make in
            make.leading.equalTo(self.playButton.snp.trailing).offset(20)
            make.centerY.equalTo(self.playButton)
        }

        self.nextButton.snp.makeConstraints { make in
            make.leading.equalTo(self.stopButton.snp.trailing).offset(20)
            make.centerY.equalTo(self.playButton)
        }

        self.timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(self.nextButton.snp.trailing).offset(20)
            make.centerY.equalTo(self.playButton)
            make.width.greaterThanOrEqualTo(100)
        }

        self.danmakuTextField.snp.makeConstraints { make in
            make.width.equalTo(130).priority(.high)
            make.width.greaterThanOrEqualTo(80)
            make.height.equalTo(24)
        }

        self.inputStack.snp.makeConstraints { make in
            make.leading.equalTo(self.timeLabel.snp.trailing).offset(10)
            make.centerY.equalTo(self.playButton)
            make.height.equalTo(26)
        }

        self.trailingStack.snp.makeConstraints { make in
            make.trailing.equalTo(-10)
            make.centerY.equalTo(self.playButton)
            make.leading.greaterThanOrEqualTo(self.inputStack.snp.trailing).offset(12)
        }
    }

    // MARK: - Compact layout

    /// 当「弹幕输入框 + 右侧全部按钮」在首选宽度下放不下时，把两个次要设置入口
    /// 收进「更多」菜单，避免默认 NSButton 被压缩成不可见。960/1280pt 下仍全部展开。
    private func updateCompactModeIfNeeded() {
        guard self.bounds.width > 0, self.inputStack.frame.minX > 0 else { return }

        let shouldCompact = self.requiredWidthForExpandedControls() > self.bounds.width
        guard shouldCompact != self.isCompactMode else { return }

        self.isCompactMode = shouldCompact
        self.mediaSettingButton.isHidden = shouldCompact
        self.danmakuSettingButton.isHidden = shouldCompact
        self.moreButton.isHidden = !shouldCompact
        self.needsLayout = true
    }

    private func requiredWidthForExpandedControls() -> CGFloat {
        let preferredTextFieldWidth: CGFloat = 130

        let configWidth = self.danmakuConfigButton.intrinsicContentSize.width
        let inputWidth = preferredTextFieldWidth + self.inputStack.spacing + configWidth

        let trailingButtons = [
            self.playerListButton,
            self.mediaSettingButton,
            self.thumbnailButton,
            self.danmakuSettingButton
        ]
        let trailingSpacing = self.trailingStack.spacing * CGFloat(max(0, trailingButtons.count - 1))
        let trailingWidth = trailingButtons.reduce(CGFloat(0)) {
            $0 + $1.intrinsicContentSize.width
        } + trailingSpacing

        // inputStack 左边距 + 输入区 + 与右侧按钮的间距 + 按钮区 + 右边距 + 一点余量。
        return self.inputStack.frame.minX + inputWidth + 12 + trailingWidth + 10 + 24
    }

    // MARK: - Overflow menu

    @objc private func showOverflowMenu(_ sender: NSButton) {
        // PlayerUIBottomView 使用非翻转坐标；maxY 之上就是控制条上方。
        let location = NSPoint(x: sender.bounds.midX, y: sender.bounds.maxY + 4)
        self.overflowMenu.popUp(positioning: nil, at: location, in: sender)
    }

    @objc private func handleOverflowMenuItem(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let action = OverflowAction(rawValue: rawValue) else {
            return
        }
        // 菜单追踪循环结束后再弹 popover，避免 popover 随菜单关闭一起被收起。
        DispatchQueue.main.async { [weak self] in
            self?.onOverflowAction?(action)
        }
    }
}
