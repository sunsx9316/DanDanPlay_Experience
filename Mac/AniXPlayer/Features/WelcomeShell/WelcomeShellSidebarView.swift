//
//  WelcomeShellSidebarView.swift
//  AniXPlayer
//
//  macOS：欢迎页左侧导航。
//

import Cocoa
import SnapKit
import Kingfisher

// MARK: - Nav item

final class WelcomeShellNavButton: WelcomeShellTapView {

    let page: WelcomeShellPage
    private let iconView = ImageView()
    private let titleLabel: Label

    var isSelected = false {
        didSet { updateSelection() }
    }

    init(page: WelcomeShellPage) {
        self.page = page
        self.titleLabel = welcomeShellLabel(
            page.title,
            font: .systemFont(ofSize: 14, weight: .medium),
            color: .labelColor
        )
        super.init(frame: .zero)
        normalBackground = .clear
        layer?.cornerRadius = 8

        iconView.image = welcomeShellSymbol(page.symbolName, pointSize: 15, weight: .medium)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.setScaling(.aspectFit)

        addSubview(iconView)
        addSubview(titleLabel)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(17)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }
        snp.makeConstraints { make in
            make.height.equalTo(38)
        }

        setAccessibilityIdentifier(page.accessibilityID)
        setAccessibilityLabel(page.title)
        updateSelection()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isEnabledForTap: Bool {
        return isTapEnabled
    }

    func updateSelection() {
        normalBackground = isSelected ? NSColor.mainColor.withAlphaComponent(0.18) : .clear
        setAccessibilityValue(isSelected ? NSLocalizedString("已选中", comment: "") : "")
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }
            self.iconView.contentTintColor = self.isSelected ? .mainColor : .secondaryLabelColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateSelection()
    }
}

// MARK: - User area

final class WelcomeShellUserAreaView: WelcomeShellTapView {

    private let avatarView = ImageView()
    private let nameLabel = welcomeShellLabel("", font: .systemFont(ofSize: 12.5, weight: .semibold), color: .labelColor)
    private let membershipLabel = welcomeShellLabel("", font: .systemFont(ofSize: 10.5), color: .secondaryLabelColor)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalBackground = .clear
        layer?.cornerRadius = 8

        avatarView.setScaling(.aspectFit)
        avatarView.wantsLayer = true
        avatarView.layer?.cornerRadius = 15
        avatarView.layer?.masksToBounds = true
        avatarView.layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.14).cgColor
        avatarView.contentTintColor = .mainColor

        membershipLabel.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.navMembership)

        addSubview(avatarView)
        addSubview(nameLabel)
        addSubview(membershipLabel)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(9)
            make.width.height.equalTo(30)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(9)
            make.trailing.equalToSuperview().offset(-10)
            make.top.equalToSuperview().offset(8)
        }
        membershipLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
        }
        snp.makeConstraints { make in
            make.height.equalTo(50)
        }

        setAccessibilityIdentifier(AccessibilityID.WelcomeShell.navUser)
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
            avatarView.image = welcomeShellSymbol("person.crop.circle.fill", pointSize: 28, weight: .regular)
            avatarView.contentTintColor = .mainColor
        }

        if let memberDate = profile?.privileges?.member, memberDate > Date() {
            let days = max(1, Calendar.current.dateComponents([.day], from: Date(), to: memberDate).day ?? 0)
            membershipLabel.text = String(
                format: NSLocalizedString("会员有效期 %d 天", comment: ""),
                days
            )
            membershipLabel.textColor = .mainColor
        } else {
            membershipLabel.text = NSLocalizedString("✨ 会员解锁更多功能", comment: "")
            membershipLabel.textColor = .secondaryLabelColor
        }
    }
}

// MARK: - Sidebar

final class WelcomeShellSidebarView: NSVisualEffectView {

    var onSelectPage: ((WelcomeShellPage) -> Void)?
    var onLogin: (() -> Void)?
    var onMembership: (() -> Void)?
    var onSettings: (() -> Void)?

    private var navButtons: [WelcomeShellPage: WelcomeShellNavButton] = [:]
    private let loginButton = WelcomeShellTapView()
    private let userArea = WelcomeShellUserAreaView()
    private let footerStack = NSStackView()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        material = .sidebar
        blendingMode = .behindWindow
        state = .followsWindowActiveState

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor

        // Brand
        let brandIcon = ImageView()
        brandIcon.image = NSApplication.shared.applicationIconImage
        brandIcon.setScaling(.aspectFit)

        let brandTitle = welcomeShellLabel(
            AppInfoHelper.appDisplayName.isEmpty ? "AniXPlayer" : AppInfoHelper.appDisplayName,
            font: .systemFont(ofSize: 15, weight: .bold),
            color: .labelColor
        )
        let version = AppInfoHelper.appVersion
        let brandVersion = welcomeShellLabel(
            version.isEmpty ? "" : "v" + version,
            font: .systemFont(ofSize: 10),
            color: .tertiaryLabelColor
        )

        let settingsButton = WelcomeShellClosureButton(
            image: welcomeShellSymbol("gearshape", pointSize: 12, weight: .medium)
        )
        settingsButton.isBordered = false
        settingsButton.contentTintColor = .secondaryLabelColor
        settingsButton.toolTip = NSLocalizedString("全局设置", comment: "")
        settingsButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.navSettings)
        settingsButton.onClick = { [weak self] in
            self?.onSettings?()
        }

        // Nav
        let navStack = NSStackView()
        navStack.orientation = .vertical
        navStack.alignment = .width
        navStack.spacing = 2

        for page in WelcomeShellPage.allCases {
            let button = WelcomeShellNavButton(page: page)
            button.onClick = { [weak self] in
                self?.onSelectPage?(page)
            }
            navButtons[page] = button
            navStack.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.width.equalTo(navStack)
            }
        }

        // Footer
        loginButton.normalBackground = NSColor.mainColor.withAlphaComponent(0.10)
        loginButton.layer?.cornerRadius = 8

        let loginIcon = ImageView()
        loginIcon.image = welcomeShellSymbol("person.crop.circle", pointSize: 15, weight: .medium)
        loginIcon.contentTintColor = .mainColor
        loginIcon.setScaling(.aspectFit)
        let loginLabel = welcomeShellLabel(
            NSLocalizedString("登录弹弹play", comment: ""),
            font: .systemFont(ofSize: 13, weight: .medium),
            color: .labelColor
        )
        loginButton.addSubview(loginIcon)
        loginButton.addSubview(loginLabel)
        loginIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(17)
        }
        loginLabel.snp.makeConstraints { make in
            make.leading.equalTo(loginIcon.snp.trailing).offset(9)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }
        loginButton.snp.makeConstraints { make in
            make.height.equalTo(38)
        }
        loginButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.navLogin)
        loginButton.setAccessibilityLabel(NSLocalizedString("登录弹弹play", comment: ""))
        loginButton.onClick = { [weak self] in
            self?.onLogin?()
        }

        userArea.onClick = { [weak self] in
            self?.onMembership?()
        }
        userArea.isHidden = true

        footerStack.orientation = .vertical
        footerStack.alignment = .width
        footerStack.spacing = 6
        footerStack.addArrangedSubview(userArea)
        footerStack.addArrangedSubview(loginButton)

        addSubview(separator)
        addSubview(brandIcon)
        addSubview(brandTitle)
        addSubview(brandVersion)
        addSubview(settingsButton)
        addSubview(navStack)
        addSubview(footerStack)

        separator.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.width.equalTo(1)
        }
        brandIcon.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(16)
            make.width.height.equalTo(28)
        }
        brandTitle.snp.makeConstraints { make in
            make.leading.equalTo(brandIcon.snp.trailing).offset(9)
            make.top.equalTo(brandIcon.snp.top).offset(1)
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
        }
        brandVersion.snp.makeConstraints { make in
            make.leading.equalTo(brandTitle)
            make.top.equalTo(brandTitle.snp.bottom).offset(1)
        }
        settingsButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalTo(brandIcon)
            make.width.height.equalTo(22)
        }
        navStack.snp.makeConstraints { make in
            make.top.equalTo(brandIcon.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(10)
        }
        footerStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(10)
            make.bottom.equalToSuperview().offset(-14)
        }
    }

    func select(_ page: WelcomeShellPage) {
        for (itemPage, button) in navButtons {
            button.isSelected = (itemPage == page)
        }
    }

    func updateSession(isLoggedIn: Bool, profile: OAuthUserProfile?) {
        loginButton.isHidden = isLoggedIn
        userArea.isHidden = !isLoggedIn
        if isLoggedIn {
            userArea.update(profile: profile)
        }
    }
}
