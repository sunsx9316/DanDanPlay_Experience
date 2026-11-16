//
//  MainTopBarView.swift
//  AniXPlayer
//
//  macOS：主窗口的 Zune 风格深色顶部导航（一级导航 + 首页二级 pivot）。
//

import Cocoa
import SnapKit
import Kingfisher

// MARK: - Palette

enum MainShellPalette {
    static let bar = NSColor(calibratedRed: 27.0 / 255.0, green: 27.0 / 255.0, blue: 30.0 / 255.0, alpha: 1)
    static let pivot = NSColor(calibratedRed: 38.0 / 255.0, green: 38.0 / 255.0, blue: 42.0 / 255.0, alpha: 1)
    static let navNormal = NSColor(calibratedRed: 185.0 / 255.0, green: 185.0 / 255.0, blue: 191.0 / 255.0, alpha: 1)
    static let pivotNormal = NSColor(calibratedRed: 154.0 / 255.0, green: 154.0 / 255.0, blue: 161.0 / 255.0, alpha: 1)
    static let secondaryText = NSColor(calibratedRed: 154.0 / 255.0, green: 154.0 / 255.0, blue: 161.0 / 255.0, alpha: 1)
    static let hairline = NSColor.white.withAlphaComponent(0.08)
}

// MARK: - Drag background

private final class MainShellTopBarDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.zoom(nil)
        } else {
            window?.performDrag(with: event)
        }
    }
}

// MARK: - Primary nav button

private final class MainShellNavButton: WelcomeShellTapView {

    let section: MainShellSection
    private let titleLabel: Label
    private let underline = NSView()
    private var isHovered = false

    var isSelected = false {
        didSet { updateSelection() }
    }

    init(section: MainShellSection) {
        self.section = section
        self.titleLabel = welcomeShellLabel(
            section.title,
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: MainShellPalette.navNormal,
            alignment: .center
        )
        super.init(frame: .zero)
        normalBackground = .clear
        layer?.cornerRadius = 0

        underline.wantsLayer = true
        underline.layer?.backgroundColor = NSColor.mainColor.cgColor

        addSubview(titleLabel)
        addSubview(underline)

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }
        underline.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalToSuperview()
            make.height.equalTo(3)
        }
        snp.makeConstraints { make in
            make.height.equalTo(74)
            make.width.greaterThanOrEqualTo(54)
        }

        setAccessibilityIdentifier(section.accessibilityID)
        setAccessibilityLabel(section.title)
        updateSelection()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let width = ceil(titleLabel.intrinsicContentSize.width) + 24
        return NSSize(width: max(54, width), height: 74)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        updateSelection()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        updateSelection()
    }

    private func updateSelection() {
        underline.isHidden = !isSelected
        titleLabel.textColor = (isSelected || isHovered) ? .white : MainShellPalette.navNormal
        setAccessibilityValue(isSelected ? NSLocalizedString("已选中", comment: "") : "")
    }
}

// MARK: - Home pivot button

private final class MainShellPivotButton: WelcomeShellTapView {

    let page: WelcomeShellPage
    private let titleLabel: Label
    private let underline = NSView()
    private var isHovered = false

    var isSelected = false {
        didSet { updateSelection() }
    }

    init(page: WelcomeShellPage) {
        self.page = page
        self.titleLabel = welcomeShellLabel(
            page.mainShellPivotTitle,
            font: .systemFont(ofSize: 11.5, weight: .medium),
            color: MainShellPalette.pivotNormal,
            alignment: .center
        )
        super.init(frame: .zero)
        normalBackground = .clear
        layer?.cornerRadius = 0

        underline.wantsLayer = true
        underline.layer?.backgroundColor = NSColor.mainColor.cgColor

        addSubview(titleLabel)
        addSubview(underline)

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(2)
            make.centerY.equalToSuperview()
        }
        underline.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(2)
        }
        snp.makeConstraints { make in
            make.height.equalTo(38)
        }

        setAccessibilityIdentifier("\(AccessibilityID.MainShell.pivotPrefix)\(page.mainShellKey)")
        setAccessibilityLabel(page.mainShellPivotTitle)
        updateSelection()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let width = ceil(titleLabel.intrinsicContentSize.width) + 4
        return NSSize(width: width, height: 38)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        updateSelection()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        updateSelection()
    }

    private func updateSelection() {
        underline.isHidden = !isSelected
        titleLabel.textColor = (isSelected || isHovered) ? .white : MainShellPalette.pivotNormal
        setAccessibilityValue(isSelected ? NSLocalizedString("已选中", comment: "") : "")
    }
}

private extension WelcomeShellPage {
    var mainShellPivotTitle: String {
        return self == .overview ? NSLocalizedString("概览", comment: "") : title
    }

    var mainShellKey: String {
        switch self {
        case .overview: return "overview"
        case .announcement: return "announcement"
        case .queue: return "queue"
        case .schedule: return "schedule"
        case .trending: return "trending"
        case .recent: return "recent"
        case .online: return "online"
        }
    }
}

// MARK: - Global search field

private final class MainShellSearchView: NSView {

    let searchField = NSSearchField()
    var onSubmit: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = MainShellPalette.hairline.cgColor

        searchField.appearance = NSAppearance(named: .darkAqua)
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 12)
        searchField.textColor = .white
        searchField.placeholderAttributedString = NSAttributedString(
            string: NSLocalizedString("搜索动画、剧集、标签", comment: ""),
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.42),
                .font: NSFont.systemFont(ofSize: 12),
            ]
        )
        searchField.sendsSearchStringImmediately = false
        searchField.target = self
        searchField.action = #selector(submit)
        searchField.setAccessibilityIdentifier(AccessibilityID.MainShell.searchField)
        searchField.setAccessibilityLabel(NSLocalizedString("全局搜索", comment: ""))

        addSubview(searchField)
        searchField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-6)
            make.centerY.equalToSuperview()
        }
        snp.makeConstraints { make in
            make.height.equalTo(28)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func submit() {
        let keyword = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        onSubmit?(keyword)
    }
}

// MARK: - User area

private final class MainShellUserAreaView: WelcomeShellTapView {

    private let avatarView = ImageView()
    private let nameLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11.5, weight: .semibold),
        color: .white
    )
    private let membershipLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 9.5),
        color: MainShellPalette.secondaryText
    )

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalBackground = .clear
        layer?.cornerRadius = 7

        avatarView.setScaling(.aspectFit)
        avatarView.wantsLayer = true
        avatarView.layer?.cornerRadius = 14
        avatarView.layer?.masksToBounds = true
        avatarView.layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.18).cgColor
        avatarView.contentTintColor = .mainColor

        addSubview(avatarView)
        addSubview(nameLabel)
        addSubview(membershipLabel)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(2)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-6)
            make.top.equalToSuperview().offset(4)
        }
        membershipLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(1)
        }
        snp.makeConstraints { make in
            make.height.equalTo(34)
            make.width.equalTo(126)
        }

        setAccessibilityIdentifier(AccessibilityID.MainShell.user)
        setAccessibilityLabel(NSLocalizedString("个人中心", comment: ""))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(profile: OAuthUserProfile?) {
        let name = profile?.displayName ?? NSLocalizedString("已登录用户", comment: "")
        nameLabel.text = name
        setAccessibilityLabel("\(NSLocalizedString("个人中心", comment: ""))，\(name)")

        if let urlString = profile?.profileImage, !urlString.isEmpty, let url = URL(string: urlString) {
            avatarView.contentTintColor = nil
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.kf.cancelDownloadTask()
            avatarView.image = welcomeShellSymbol("person.crop.circle.fill", pointSize: 26, weight: .regular)
            avatarView.contentTintColor = .mainColor
        }

        if let memberDate = profile?.privileges?.member, memberDate > Date() {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            membershipLabel.text = String(
                format: NSLocalizedString("会员至 %@", comment: ""),
                formatter.string(from: memberDate)
            )
            membershipLabel.textColor = MainShellPalette.secondaryText
        } else {
            membershipLabel.text = NSLocalizedString("未开通会员", comment: "")
            membershipLabel.textColor = MainShellPalette.secondaryText
        }
    }
}

// MARK: - Top bar

final class MainTopBarView: NSView {

    var onSelectSection: ((MainShellSection) -> Void)?
    var onSelectPivot: ((WelcomeShellPage) -> Void)?
    var onSubmitSearch: ((String) -> Void)?
    var onLogin: (() -> Void)?
    var onShowMembership: (() -> Void)?
    var onShowSettings: (() -> Void)?

    private let primaryBackground = MainShellTopBarDragView()
    private let pivotRow = NSView()
    private let pivotBackground = MainShellTopBarDragView()
    private let pivotStack = NSStackView()
    private let navStack = NSStackView()
    private let searchView = MainShellSearchView()
    private let userArea = MainShellUserAreaView()
    private let loginButton = WelcomeShellTapView()
    private let accountStack = NSStackView()
    private let gearButton = WelcomeShellTapView()
    private var navButtons: [MainShellSection: MainShellNavButton] = [:]
    private var pivotButtons: [WelcomeShellPage: MainShellPivotButton] = [:]

    var preferredHeight: CGFloat {
        return pivotRow.isHidden ? 74 : 112
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = MainShellPalette.bar.cgColor
        layer?.masksToBounds = true
        setAccessibilityIdentifier(AccessibilityID.MainShell.topBar)

        // 一级导航背景：留出红绿灯区域，品牌从 x=86 开始。
        primaryBackground.wantsLayer = true
        primaryBackground.layer?.backgroundColor = MainShellPalette.bar.cgColor
        addSubview(primaryBackground)
        primaryBackground.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(74)
        }

        let brandIcon = ImageView()
        brandIcon.image = NSApplication.shared.applicationIconImage
        brandIcon.setScaling(.aspectFit)

        let brandTitle = welcomeShellLabel(
            "弹弹play",
            font: .systemFont(ofSize: 16, weight: .bold),
            color: .white
        )
        let version = AppInfoHelper.appVersion
        let brandVersion = welcomeShellLabel(
            version.isEmpty ? "" : "v" + version,
            font: .systemFont(ofSize: 9.5),
            color: MainShellPalette.secondaryText
        )

        let brandText = NSStackView(views: [brandTitle, brandVersion])
        brandText.orientation = .vertical
        brandText.alignment = .leading
        brandText.spacing = 1

        addSubview(brandIcon)
        addSubview(brandText)

        brandIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(86)
            make.centerY.equalTo(primaryBackground)
            make.width.height.equalTo(32)
        }
        brandText.snp.makeConstraints { make in
            make.leading.equalTo(brandIcon.snp.trailing).offset(10)
            make.centerY.equalTo(primaryBackground)
        }

        // 一级导航
        navStack.orientation = .horizontal
        navStack.alignment = .centerY
        navStack.spacing = 2
        addSubview(navStack)

        for section in MainShellSection.allCases {
            let button = MainShellNavButton(section: section)
            button.onClick = { [weak self] in
                self?.onSelectSection?(section)
            }
            button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            navButtons[section] = button
            navStack.addArrangedSubview(button)
        }
        navStack.snp.makeConstraints { make in
            make.leading.equalTo(brandText.snp.trailing).offset(26)
            make.centerY.equalTo(primaryBackground)
            make.height.equalTo(74)
        }

        // 右侧：搜索 + 登录/用户 + 设置
        gearButton.normalBackground = .clear
        gearButton.layer?.cornerRadius = 7
        gearButton.toolTip = NSLocalizedString("全局设置", comment: "")
        gearButton.setAccessibilityIdentifier(AccessibilityID.MainShell.settings)
        gearButton.setAccessibilityLabel(NSLocalizedString("全局设置", comment: ""))
        gearButton.onClick = { [weak self] in
            self?.onShowSettings?()
        }
        let gearIcon = ImageView()
        gearIcon.image = welcomeShellSymbol("gearshape", pointSize: 15, weight: .medium)
        gearIcon.contentTintColor = MainShellPalette.navNormal
        gearIcon.setScaling(.aspectFit)
        gearButton.addSubview(gearIcon)
        gearIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(18)
        }
        gearButton.snp.makeConstraints { make in
            make.width.height.equalTo(28)
        }

        loginButton.normalBackground = NSColor.white.withAlphaComponent(0.06)
        loginButton.layer?.cornerRadius = 7
        loginButton.layer?.borderWidth = 1
        loginButton.borderColorProvider = {
            NSColor.white.withAlphaComponent(0.24)
        }
        loginButton.setAccessibilityIdentifier(AccessibilityID.MainShell.login)
        loginButton.setAccessibilityLabel(NSLocalizedString("登录", comment: ""))
        loginButton.onClick = { [weak self] in
            self?.onLogin?()
        }
        let loginLabel = welcomeShellLabel(
            NSLocalizedString("登录", comment: ""),
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: .white,
            alignment: .center
        )
        loginButton.addSubview(loginLabel)
        loginLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8)
            make.centerY.equalToSuperview()
        }
        loginButton.snp.makeConstraints { make in
            make.width.equalTo(62)
            make.height.equalTo(28)
        }

        userArea.isHidden = true
        userArea.onClick = { [weak self] in
            self?.onShowMembership?()
        }

        accountStack.orientation = .horizontal
        accountStack.alignment = .centerY
        accountStack.spacing = 0
        accountStack.detachesHiddenViews = true
        accountStack.addArrangedSubview(userArea)
        accountStack.addArrangedSubview(loginButton)

        let rightStack = NSStackView(views: [searchView, accountStack, gearButton])
        rightStack.orientation = .horizontal
        rightStack.alignment = .centerY
        rightStack.spacing = 10
        addSubview(rightStack)

        searchView.snp.makeConstraints { make in
            make.width.equalTo(190).priority(.high)
            make.width.greaterThanOrEqualTo(140)
        }
        rightStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-22)
            make.centerY.equalTo(primaryBackground)
        }
        navStack.snp.makeConstraints { make in
            make.trailing.lessThanOrEqualTo(rightStack.snp.leading).offset(-16)
        }

        // 首页二级 pivot
        pivotRow.wantsLayer = true
        addSubview(pivotRow)
        pivotRow.snp.makeConstraints { make in
            make.top.equalTo(primaryBackground.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(38)
        }

        pivotBackground.wantsLayer = true
        pivotBackground.layer?.backgroundColor = MainShellPalette.pivot.cgColor
        pivotRow.addSubview(pivotBackground)
        pivotBackground.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        pivotStack.orientation = .horizontal
        pivotStack.alignment = .centerY
        pivotStack.spacing = 24
        pivotRow.addSubview(pivotStack)
        for page in WelcomeShellPage.allCases {
            let button = MainShellPivotButton(page: page)
            button.onClick = { [weak self] in
                self?.onSelectPivot?(page)
            }
            pivotButtons[page] = button
            pivotStack.addArrangedSubview(button)
        }
        pivotStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(86)
            make.centerY.equalToSuperview()
            make.height.equalTo(38)
        }

        // 一级导航底部分隔线（pivot 可见时压在深色条与 pivot 的交界处）。
        let hairline = NSView()
        hairline.wantsLayer = true
        hairline.layer?.backgroundColor = MainShellPalette.hairline.cgColor
        addSubview(hairline)
        hairline.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(primaryBackground.snp.bottom)
            make.height.equalTo(1)
        }

        searchView.onSubmit = { [weak self] keyword in
            guard let self = self else { return }
            self.window?.makeFirstResponder(nil)
            self.onSubmitSearch?(keyword)
        }
    }

    // MARK: Public

    func setSelectedSection(_ section: MainShellSection) {
        for (item, button) in navButtons {
            button.isSelected = item == section
        }
    }

    func setSelectedPivot(_ page: WelcomeShellPage) {
        for (item, button) in pivotButtons {
            button.isSelected = item == page
        }
    }

    func setPivotVisible(_ visible: Bool) {
        pivotRow.isHidden = !visible
        if visible {
            layer?.backgroundColor = MainShellPalette.bar.cgColor
        }
    }

    func updateSession(isLoggedIn: Bool, profile: OAuthUserProfile?) {
        userArea.isHidden = !isLoggedIn
        loginButton.isHidden = isLoggedIn
        if isLoggedIn {
            userArea.update(profile: profile)
        }
    }
}
