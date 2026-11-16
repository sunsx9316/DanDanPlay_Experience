//
//  WelcomeShellComponents.swift
//  AniXPlayer
//
//  macOS：Windows 式欢迎页外壳的通用视觉组件。
//

import Cocoa
import SnapKit
import Kingfisher

// MARK: - Helpers

func welcomeShellLabel(
    _ text: String,
    font: NSFont,
    color: NSColor,
    lines: Int = 1,
    alignment: NSTextAlignment = .left,
    lineBreakMode: NSLineBreakMode = .byTruncatingTail
) -> Label {
    let label = Label(labelWithString: text)
    label.font = font
    label.textColor = color
    label.alignment = alignment
    label.maximumNumberOfLines = lines
    label.lineBreakMode = lineBreakMode
    if lines != 1 {
        label.cell?.wraps = true
        label.cell?.isScrollable = false
    }
    return label
}

func welcomeShellSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight = .regular) -> NSImage? {
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
}

private func welcomeShellRelativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Flipped document view

final class WelcomeShellFlippedView: NSView {
    override var isFlipped: Bool {
        return true
    }
}

// MARK: - Scroll page base

/// 可滚动的页面基类：内容用垂直 StackView 排列，由子类添加卡片。
class WelcomeShellScrollPageViewController: ViewController {

    let scrollView: ScrollView<WelcomeShellFlippedView>
    let contentView: WelcomeShellFlippedView
    private var didSetInitialScroll = false
    private let bottomSpacer = NSView()
    private var didAddBottomSpacer = false
    let contentStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.distribution = .fill
        stack.spacing = 14
        stack.detachesHiddenViews = true
        stack.setHuggingPriority(.required, for: .vertical)
        return stack
    }()

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 620))
    }

    override init() {
        let content = WelcomeShellFlippedView()
        self.contentView = content
        self.scrollView = ScrollView(containerView: content)
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none

        contentView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.leading.trailing.equalToSuperview().inset(22)
            make.bottom.equalToSuperview().offset(-24)
        }

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !didSetInitialScroll else { return }
        didSetInitialScroll = true
        scrollToTop()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutContent()
    }

    func scrollToTop() {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func layoutContent() {
        let clipSize = scrollView.contentView.bounds.size
        guard clipSize.width > 0 else { return }

        if contentView.frame.width != clipSize.width {
            contentView.frame.size.width = clipSize.width
            contentView.layoutSubtreeIfNeeded()
        }

        if !didAddBottomSpacer {
            didAddBottomSpacer = true
            bottomSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
            bottomSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            contentStack.addArrangedSubview(bottomSpacer)
            bottomSpacer.snp.makeConstraints { make in
                make.width.equalTo(contentStack)
                make.height.greaterThanOrEqualTo(0)
            }
        }

        let stackHeight = contentStack.fittingSize.height
        let contentHeight = max(stackHeight + 42, clipSize.height)
        if abs(contentView.frame.height - contentHeight) > 0.5 {
            contentView.frame.size.height = contentHeight
        }
    }

    func addFullWidth(_ view: NSView, spacingAfter: CGFloat? = nil) {
        contentStack.addArrangedSubview(view)
        view.snp.makeConstraints { make in
            make.width.equalTo(contentStack)
        }
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        if let spacing = spacingAfter {
            contentStack.setCustomSpacing(spacing, after: view)
        }
    }
}

// MARK: - Page header

final class WelcomeShellPageHeaderView: NSView {

    let trailingStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        return stack
    }()

    private let titleLabel: Label
    private let subtitleLabel: Label?

    init(title: String, subtitle: String? = nil) {
        self.titleLabel = welcomeShellLabel(
            title,
            font: .systemFont(ofSize: 24, weight: .bold),
            color: .labelColor
        )
        if let subtitle = subtitle, !subtitle.isEmpty {
            self.subtitleLabel = welcomeShellLabel(
                subtitle,
                font: .systemFont(ofSize: 12),
                color: .secondaryLabelColor
            )
        } else {
            self.subtitleLabel = nil
        }
        super.init(frame: .zero)

        titleLabel.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.pageTitle)
        addSubview(titleLabel)
        addSubview(trailingStack)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)
        if let subtitleLabel = subtitleLabel {
            textStack.addArrangedSubview(subtitleLabel)
        }
        addSubview(textStack)

        textStack.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(trailingStack.snp.leading).offset(-12)
        }
        trailingStack.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
        snp.makeConstraints { make in
            make.height.equalTo(52)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Card

final class WelcomeShellCardView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        updateColors()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        updateColors()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }
            let base = NSColor.controlBackgroundColor
            self.layer?.backgroundColor = base.cgColor
            self.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        }
    }
}

// MARK: - Tap view

class WelcomeShellTapView: NSView {

    var onClick: (() -> Void)?
    var isTapEnabled = true {
        didSet { updateColors() }
    }
    var normalBackground: NSColor = .clear {
        didSet { updateColors() }
    }
    /// 在 effectiveAppearance 内解析动态颜色，避免深浅色切换后保留旧值。
    var normalBackgroundProvider: (() -> NSColor)? {
        didSet { updateColors() }
    }
    var borderColorProvider: (() -> NSColor?)? {
        didSet { updateColors() }
    }

    private var isHovered = false {
        didSet { updateColors() }
    }
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        updateColors()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isTapEnabled, isEnabledForTap else { return }
        onClick?()
    }

    override func accessibilityPerformPress() -> Bool {
        guard isTapEnabled, isEnabledForTap else { return false }
        onClick?()
        return true
    }

    var isEnabledForTap: Bool {
        return true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }
            let base = self.normalBackgroundProvider?() ?? self.normalBackground
            let background: NSColor
            if self.isTapEnabled && self.isHovered {
                background = base.blended(withFraction: 0.10, of: .mainColor) ?? base
            } else {
                background = base
            }
            self.layer?.backgroundColor = background.cgColor
            if let border = self.borderColorProvider?() {
                self.layer?.borderColor = border.cgColor
            }
        }
    }
}

// MARK: - Closure button

final class WelcomeShellClosureButton: NSButton {

    var onClick: (() -> Void)?

    init(title: String = "", image: NSImage? = nil) {
        super.init(frame: .zero)
        self.title = title
        self.image = image
        target = self
        action = #selector(handleClick)
        bezelStyle = .rounded
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleClick() {
        onClick?()
    }
}

// MARK: - Card header

final class WelcomeShellCardHeaderView: NSView {

    let trailingStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        return stack
    }()

    private let button: WelcomeShellClosureButton

    init(
        title: String,
        hint: String? = nil,
        symbolName: String? = nil,
        identifier: String,
        onTap: (() -> Void)?
    ) {
        self.button = WelcomeShellClosureButton()
        super.init(frame: .zero)

        button.isBordered = false
        button.alignment = .left
        button.contentTintColor = .mainColor
        button.focusRingType = .none
        button.onClick = onTap

        if let symbolName = symbolName {
            button.image = welcomeShellSymbol(symbolName, pointSize: 15, weight: .semibold)
            button.imagePosition = .imageLeading
        } else {
            button.imagePosition = .noImage
        }

        let attributed = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        if let hint = hint, !hint.isEmpty {
            attributed.append(NSAttributedString(
                string: "  " + hint,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            ))
        }
        button.attributedTitle = attributed
        button.setAccessibilityIdentifier(identifier)
        button.setAccessibilityLabel(hint.map { "\(title)，\($0)" } ?? title)

        addSubview(button)
        addSubview(trailingStack)

        button.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(trailingStack.snp.leading).offset(-10)
        }
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trailingStack.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
        snp.makeConstraints { make in
            make.height.equalTo(34)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - State view

final class WelcomeShellStateView: NSView {

    private let titleLabel = welcomeShellLabel("", font: .systemFont(ofSize: 13, weight: .medium), color: .secondaryLabelColor, lines: 2, alignment: .center, lineBreakMode: .byWordWrapping)
    private let detailLabel = welcomeShellLabel("", font: .systemFont(ofSize: 11), color: .tertiaryLabelColor, lines: 2, alignment: .center, lineBreakMode: .byWordWrapping)
    private let actionButton = WelcomeShellClosureButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        actionButton.isHidden = true
        actionButton.controlSize = .small
        actionButton.bezelStyle = .rounded
        actionButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.statusAction)

        let stack = NSStackView(views: [titleLabel, detailLabel, actionButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.setCustomSpacing(8, after: detailLabel)
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
        setAccessibilityIdentifier(AccessibilityID.WelcomeShell.status)
    }

    func configure(
        title: String,
        detail: String? = nil,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        titleLabel.text = title
        titleLabel.isHidden = title.isEmpty
        detailLabel.text = detail ?? ""
        detailLabel.isHidden = (detail ?? "").isEmpty

        if let actionTitle = actionTitle, let onAction = onAction {
            actionButton.title = actionTitle
            actionButton.onClick = onAction
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
            actionButton.onClick = nil
        }
        isHidden = false
    }

    func reset() {
        titleLabel.text = ""
        detailLabel.text = ""
        actionButton.isHidden = true
        actionButton.onClick = nil
    }
}

// MARK: - Action tile

final class WelcomeShellActionTileView: WelcomeShellTapView {

    private let iconView = ImageView()
    private let titleLabel: Label

    init(title: String, symbolName: String, identifier: String, emphasized: Bool = false) {
        self.titleLabel = welcomeShellLabel(
            title,
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor,
            alignment: .center
        )
        super.init(frame: .zero)

        normalBackgroundProvider = {
            emphasized
                ? NSColor.mainColor.withAlphaComponent(0.12)
                : NSColor.controlBackgroundColor.withAlphaComponent(0.65)
        }
        borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.35)
        }
        layer?.cornerRadius = 10
        layer?.borderWidth = 1

        iconView.image = welcomeShellSymbol(symbolName, pointSize: 22, weight: .medium)
        iconView.contentTintColor = .mainColor
        iconView.setScaling(.aspectFit)

        addSubview(iconView)
        addSubview(titleLabel)

        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(26)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(8)
        }

        setAccessibilityIdentifier(identifier)
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Progress bar

final class WelcomeShellProgressBar: NSView {

    var progress: Double = 0 {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 0, bounds.height > 0 else { return }
        let radius = bounds.height / 2

        NSColor.separatorColor.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        let clamped = CGFloat(max(0, min(progress, 1)))
        guard clamped > 0 else { return }
        var fillRect = bounds
        fillRect.size.width = max(bounds.height, bounds.width * clamped)
        NSColor.mainColor.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - Continue playback card

final class WelcomeShellContinueCardView: WelcomeShellTapView {

    private let titleLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 12.5, weight: .semibold),
        color: .labelColor,
        lines: 2,
        lineBreakMode: .byTruncatingMiddle
    )
    private let detailLabel = welcomeShellLabel("", font: .systemFont(ofSize: 10.5), color: .secondaryLabelColor)
    private let progressBar = WelcomeShellProgressBar()
    private let thumbnail = NSView()
    private let playIcon = ImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalBackgroundProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.65)
        }
        borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.35)
        }
        layer?.borderWidth = 1

        thumbnail.wantsLayer = true
        thumbnail.layer?.cornerRadius = 8
        thumbnail.layer?.cornerCurve = .continuous
        thumbnail.layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.12).cgColor
        thumbnail.layer?.borderWidth = 1
        thumbnail.layer?.borderColor = NSColor.mainColor.withAlphaComponent(0.20).cgColor

        playIcon.image = welcomeShellSymbol("play.fill", pointSize: 18, weight: .semibold)
        playIcon.contentTintColor = .mainColor
        playIcon.setScaling(.aspectFit)
        thumbnail.addSubview(playIcon)
        playIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(18)
        }

        addSubview(thumbnail)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(progressBar)

        thumbnail.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(52)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalTo(thumbnail.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
        }
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(3)
            make.leading.trailing.equalTo(titleLabel)
        }
        progressBar.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-11)
            make.height.equalTo(3)
        }
        snp.makeConstraints { make in
            make.height.equalTo(80)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: WelcomeRecentItem) {
        let fileName = (item.path as NSString).lastPathComponent
        titleLabel.text = fileName
        let folder = ((item.path as NSString).deletingLastPathComponent as NSString).lastPathComponent
        var parts: [String] = []
        if !folder.isEmpty { parts.append(folder) }
        if let progress = item.progress, progress > 0.01 {
            parts.append(String(format: NSLocalizedString("已观看 %d%%", comment: ""), Int(round(progress * 100))))
            progressBar.progress = progress
            progressBar.isHidden = false
        } else {
            parts.append(NSLocalizedString("尚未记录进度", comment: ""))
            progressBar.isHidden = true
        }
        parts.append(welcomeShellRelativeDate(Date(timeIntervalSince1970: item.lastOpened)))
        detailLabel.text = parts.joined(separator: " · ")
        toolTip = item.path
        setAccessibilityLabel("\(fileName)，\(detailLabel.text ?? "")")
    }
}

// MARK: - Announcement card

final class WelcomeShellAnnouncementCardView: WelcomeShellTapView {

    private let imageView = ImageView()
    private let titleLabel = welcomeShellLabel("", font: .systemFont(ofSize: 17, weight: .semibold), color: .labelColor, lines: 2, lineBreakMode: .byWordWrapping)
    private let descriptionLabel = welcomeShellLabel("", font: .systemFont(ofSize: 12), color: .secondaryLabelColor, lines: 3, lineBreakMode: .byWordWrapping)
    private var imageHeightConstraint: Constraint?
    private var imageBottomConstraint: Constraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalBackgroundProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.55)
        }
        borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.35)
        }
        layer?.borderWidth = 1

        imageView.setScaling(.aspectFill)
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.cornerCurve = .continuous
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = NSColor.placeholderColor.cgColor

        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)

        imageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            imageHeightConstraint = make.height.equalTo(160).constraint
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(14)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-14)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with banner: BannerPageItem) {
        titleLabel.text = banner.title
        descriptionLabel.text = banner.description
        titleLabel.isHidden = banner.title.isEmpty
        descriptionLabel.isHidden = banner.description.isEmpty

        if let url = URL(string: banner.imageUrl), !banner.imageUrl.isEmpty {
            imageView.isHidden = false
            imageHeightConstraint?.update(offset: 160)
            imageView.kf.setImage(with: url)
        } else {
            imageView.isHidden = true
            imageHeightConstraint?.update(offset: 0)
        }
        setAccessibilityLabel([banner.title, banner.description].filter { !$0.isEmpty }.joined(separator: "，"))
        toolTip = banner.url.isEmpty ? nil : banner.url
    }
}

// MARK: - Overview queue card

final class WelcomeShellQueueCardView: WelcomeShellTapView {

    private let posterView = ImageView()
    private let titleLabel = welcomeShellLabel("", font: .systemFont(ofSize: 12.5, weight: .semibold), color: .labelColor, lines: 2)
    private let episodeLabel = welcomeShellLabel("", font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
    private let descriptionLabel = welcomeShellLabel("", font: .systemFont(ofSize: 10.5), color: .tertiaryLabelColor)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalBackgroundProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.55)
        }
        borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.35)
        }
        layer?.borderWidth = 1

        posterView.setScaling(.aspectFill)
        posterView.wantsLayer = true
        posterView.layer?.cornerRadius = 6
        posterView.layer?.cornerCurve = .continuous
        posterView.layer?.masksToBounds = true
        posterView.layer?.backgroundColor = NSColor.placeholderColor.cgColor

        addSubview(posterView)
        addSubview(titleLabel)
        addSubview(episodeLabel)
        addSubview(descriptionLabel)

        posterView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(6)
            make.width.equalTo(posterView.snp.height).multipliedBy(0.72)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(9)
            make.leading.equalTo(posterView.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
        }
        episodeLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(3)
            make.leading.trailing.equalTo(titleLabel)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(episodeLabel.snp.bottom).offset(2)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-8)
        }
        snp.makeConstraints { make in
            make.height.equalTo(86)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: WelcomeQueueCardItem) {
        titleLabel.text = item.animeTitle
        episodeLabel.text = item.episodeTitle
        descriptionLabel.text = item.description
        if let url = URL(string: item.imageUrl), !item.imageUrl.isEmpty {
            posterView.kf.setImage(with: url)
        } else {
            posterView.image = nil
        }
        setAccessibilityLabel([item.animeTitle, item.episodeTitle, item.description].filter { !$0.isEmpty }.joined(separator: "，"))
    }
}

// MARK: - Queue page row

final class WelcomeShellQueueRowView: WelcomeShellTapView {

    private let posterView = ImageView()
    private let titleLabel = welcomeShellLabel("", font: .systemFont(ofSize: 15, weight: .semibold), color: .labelColor, lines: 2)
    private let episodeLabel = welcomeShellLabel("", font: .systemFont(ofSize: 12), color: .secondaryLabelColor, lines: 2)
    private let descriptionLabel = welcomeShellLabel("", font: .systemFont(ofSize: 11), color: .tertiaryLabelColor, lines: 2)
    private let dateLabel = welcomeShellLabel("", font: .systemFont(ofSize: 11), color: .mainColor)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalBackgroundProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.55)
        }
        borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.35)
        }
        layer?.borderWidth = 1

        posterView.setScaling(.aspectFill)
        posterView.wantsLayer = true
        posterView.layer?.cornerRadius = 7
        posterView.layer?.cornerCurve = .continuous
        posterView.layer?.masksToBounds = true
        posterView.layer?.backgroundColor = NSColor.placeholderColor.cgColor

        addSubview(posterView)
        addSubview(titleLabel)
        addSubview(episodeLabel)
        addSubview(descriptionLabel)
        addSubview(dateLabel)

        posterView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(10)
            make.width.equalTo(posterView.snp.height).multipliedBy(0.72)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(13)
            make.leading.equalTo(posterView.snp.trailing).offset(14)
            make.trailing.equalToSuperview().offset(-14)
        }
        episodeLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
            make.leading.trailing.equalTo(titleLabel)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(episodeLabel.snp.bottom).offset(3)
            make.leading.trailing.equalTo(titleLabel)
        }
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(5)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }
        snp.makeConstraints { make in
            make.height.equalTo(126)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: WelcomeQueueCardItem) {
        titleLabel.text = item.animeTitle
        episodeLabel.text = item.episodeTitle
        descriptionLabel.text = item.description

        var dateParts: [String] = []
        if !item.airDateText.isEmpty {
            dateParts.append(String(format: NSLocalizedString("更新 %@", comment: ""), item.airDateText))
        }
        dateParts.append(item.isOnAir ? NSLocalizedString("连载中", comment: "") : NSLocalizedString("已完结", comment: ""))
        dateLabel.text = dateParts.joined(separator: " · ")

        if let url = URL(string: item.imageUrl), !item.imageUrl.isEmpty {
            posterView.kf.setImage(with: url)
        } else {
            posterView.image = nil
        }
        setAccessibilityLabel([item.animeTitle, item.episodeTitle, item.description].filter { !$0.isEmpty }.joined(separator: "，"))
    }
}

// MARK: - Recent playback row

final class WelcomeShellRecentRowView: WelcomeShellTapView {

    var onRemove: (() -> Void)?

    private let titleLabel = welcomeShellLabel("", font: .systemFont(ofSize: 13.5, weight: .semibold), color: .labelColor)
    private let subtitleLabel = welcomeShellLabel("", font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
    private let dateLabel = welcomeShellLabel("", font: .systemFont(ofSize: 10.5), color: .tertiaryLabelColor)
    private let progressBar = WelcomeShellProgressBar()
    private let thumbnail = NSView()
    private let playIcon = ImageView()
    private let removeButton = WelcomeShellClosureButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalBackgroundProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.55)
        }
        borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.35)
        }
        layer?.borderWidth = 1

        thumbnail.wantsLayer = true
        thumbnail.layer?.cornerRadius = 7
        thumbnail.layer?.cornerCurve = .continuous
        thumbnail.layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.10).cgColor
        playIcon.image = welcomeShellSymbol("play.fill", pointSize: 16, weight: .semibold)
        playIcon.contentTintColor = .mainColor
        playIcon.setScaling(.aspectFit)
        thumbnail.addSubview(playIcon)
        playIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
        }

        removeButton.image = welcomeShellSymbol("xmark", pointSize: 10, weight: .semibold)
        removeButton.isBordered = false
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.toolTip = NSLocalizedString("从最近播放中移除", comment: "")
        removeButton.onClick = { [weak self] in
            self?.onRemove?()
        }

        addSubview(thumbnail)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(dateLabel)
        addSubview(progressBar)
        addSubview(removeButton)

        thumbnail.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.equalTo(72)
            make.height.equalTo(44)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(11)
            make.leading.equalTo(thumbnail.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(removeButton.snp.leading).offset(-8)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(dateLabel.snp.leading).offset(-8)
        }
        progressBar.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(5)
            make.leading.equalTo(titleLabel)
            make.width.equalTo(160)
            make.height.equalTo(3)
        }
        dateLabel.snp.makeConstraints { make in
            make.leading.equalTo(progressBar.snp.trailing).offset(8)
            make.centerY.equalTo(subtitleLabel)
            make.trailing.lessThanOrEqualTo(removeButton.snp.leading).offset(-8)
        }
        removeButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }
        snp.makeConstraints { make in
            make.height.equalTo(66)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: WelcomeRecentItem, index: Int) {
        let fileName = (item.path as NSString).lastPathComponent
        let folder = (item.path as NSString).deletingLastPathComponent
        titleLabel.text = fileName
        subtitleLabel.text = folder
        dateLabel.text = welcomeShellRelativeDate(Date(timeIntervalSince1970: item.lastOpened))

        if let progress = item.progress, progress > 0.01 {
            progressBar.progress = progress
            progressBar.isHidden = false
            dateLabel.text = String(
                format: NSLocalizedString("已观看 %d%% · %@", comment: ""),
                Int(round(progress * 100)),
                welcomeShellRelativeDate(Date(timeIntervalSince1970: item.lastOpened))
            )
        } else {
            progressBar.isHidden = true
        }
        removeButton.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.recentRemovePrefix)\(index)")
        setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.recentItemPrefix)\(index)")
        setAccessibilityLabel("\(fileName)，\(subtitleLabel.text ?? "")")
        toolTip = item.path
    }
}

// MARK: - Poster tile

final class WelcomeShellPosterTileView: WelcomeShellTapView {

    private let posterView = ImageView()
    private let ratingBadge = welcomeShellLabel("", font: .systemFont(ofSize: 10, weight: .bold), color: .white, alignment: .center)
    private let favoriteMark = ImageView()
    private let titleLabel = welcomeShellLabel("", font: .systemFont(ofSize: 12), color: .labelColor, lines: 2, lineBreakMode: .byWordWrapping)
    private let subtitleLabel = welcomeShellLabel("", font: .systemFont(ofSize: 10.5), color: .secondaryLabelColor)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalBackground = .clear

        posterView.setScaling(.aspectFill)
        posterView.wantsLayer = true
        posterView.layer?.cornerRadius = 7
        posterView.layer?.cornerCurve = .continuous
        posterView.layer?.masksToBounds = true
        posterView.layer?.backgroundColor = NSColor.placeholderColor.cgColor

        ratingBadge.wantsLayer = true
        ratingBadge.layer?.cornerRadius = 4
        ratingBadge.layer?.masksToBounds = true
        ratingBadge.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor

        favoriteMark.image = welcomeShellSymbol("heart.fill", pointSize: 12, weight: .semibold)
        favoriteMark.contentTintColor = .mainColor
        favoriteMark.setScaling(.aspectFit)
        favoriteMark.wantsLayer = true
        favoriteMark.layer?.cornerRadius = 9
        favoriteMark.layer?.masksToBounds = true
        updateFavoriteMarkColor()

        addSubview(posterView)
        posterView.addSubview(ratingBadge)
        addSubview(favoriteMark)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        posterView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(posterView.snp.width).multipliedBy(1.4)
        }
        ratingBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(5)
            make.bottom.equalToSuperview().offset(-5)
            make.height.equalTo(16)
            make.width.greaterThanOrEqualTo(30)
        }
        favoriteMark.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.trailing.equalToSuperview().offset(-6)
            make.width.height.equalTo(18)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(posterView.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(2)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.leading.trailing.equalToSuperview().inset(2)
            make.bottom.lessThanOrEqualToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateFavoriteMarkColor()
    }

    private func updateFavoriteMarkColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            self?.favoriteMark.layer?.backgroundColor = NSColor.windowBackgroundColor
                .withAlphaComponent(0.75).cgColor
        }
    }

    func configure(with item: BangumiIntro, showsFavorite: Bool = true) {
        titleLabel.text = item.animeTitle
        if let url = URL(string: item.imageUrl), !item.imageUrl.isEmpty {
            posterView.kf.setImage(with: url)
        } else {
            posterView.image = nil
        }

        if item.rating > 0 {
            ratingBadge.text = String(format: "⭐ %.1f", item.rating)
            ratingBadge.isHidden = false
        } else {
            ratingBadge.isHidden = true
        }

        favoriteMark.isHidden = !(showsFavorite && item.isFavorited)
        subtitleLabel.text = item.isOnAir
            ? WelcomeShellDataMapper.weekdayTitle(for: item.airDay)
            : NSLocalizedString("已完结", comment: "")

        var parts = [item.animeTitle]
        if item.rating > 0 {
            parts.append(String(format: NSLocalizedString("评分 %.1f", comment: ""), item.rating))
        }
        if item.isFavorited {
            parts.append(NSLocalizedString("已关注", comment: ""))
        }
        setAccessibilityLabel(parts.joined(separator: "，"))
    }
}

// MARK: - Poster grid (non-scrolling, used by Overview)

final class WelcomeShellPosterGridView: NSView {

    var onSelect: ((BangumiIntro) -> Void)?
    var onHeightChange: (() -> Void)?

    private let rowStack = NSStackView()
    private var items: [BangumiIntro] = []
    private var heightConstraint: Constraint?
    private var lastWidth: CGFloat = 0
    private var lastSignature: [Int] = []
    private var lastHeight: CGFloat = -1
    private let minimumTileWidth: CGFloat = 128
    private let spacing: CGFloat = 12

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        rowStack.orientation = .vertical
        rowStack.alignment = .width
        rowStack.spacing = spacing
        addSubview(rowStack)
        rowStack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        snp.makeConstraints { make in
            heightConstraint = make.height.equalTo(0).constraint
        }
    }

    override func layout() {
        super.layout()
        rebuildIfNeeded()
    }

    func reload(items: [BangumiIntro]) {
        self.items = items
        lastSignature = []
        rebuildIfNeeded()
    }

    private func rebuildIfNeeded() {
        let width = bounds.width
        guard width > 0 else { return }
        let signature = items.map { $0.animeId }
        guard width != lastWidth || signature != lastSignature else { return }
        lastWidth = width
        lastSignature = signature

        rowStack.arrangedSubviews.forEach {
            rowStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !items.isEmpty else {
            updateHeight(0)
            return
        }

        let columns = max(1, Int((width + spacing) / (minimumTileWidth + spacing)))
        let tileWidth = floor((width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let tileHeight = ceil(tileWidth * 1.4 + 62)

        var index = 0
        while index < items.count {
            let upper = min(index + columns, items.count)
            let rowItems = Array(items[index..<upper])
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .top
            row.distribution = .fillEqually
            row.spacing = spacing

            for item in rowItems {
                let tile = WelcomeShellPosterTileView()
                tile.configure(with: item)
                tile.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.overviewScheduleItemPrefix)\(item.animeId)")
                tile.onClick = { [weak self] in
                    self?.onSelect?(item)
                }
                row.addArrangedSubview(tile)
                tile.snp.makeConstraints { make in
                    make.height.equalTo(tileHeight)
                }
            }

            // 最后一行不足时补透明占位，保证卡片宽度一致。
            if rowItems.count < columns {
                for _ in rowItems.count..<columns {
                    let spacer = NSView()
                    row.addArrangedSubview(spacer)
                    spacer.snp.makeConstraints { make in
                        make.height.equalTo(tileHeight)
                    }
                }
            }

            rowStack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.width.equalTo(rowStack)
            }
            index = upper
        }

        let rows = ceil(Double(items.count) / Double(columns))
        let height = CGFloat(rows) * tileHeight + CGFloat(max(0, rows - 1)) * spacing
        updateHeight(height)
    }

    private func updateHeight(_ height: CGFloat) {
        guard abs(lastHeight - height) > 0.5 else { return }
        lastHeight = height
        heightConstraint?.update(offset: height)
        invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in
            self?.onHeightChange?()
        }
    }
}
