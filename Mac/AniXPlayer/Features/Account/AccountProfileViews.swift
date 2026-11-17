//
//  AccountProfileViews.swift
//  AniXPlayer
//
//  macOS only：账号资料窗口的头部、操作行与 bangumi.tv 关联卡片。
//

import Cocoa
import Kingfisher
import SnapKit

// MARK: - Header

final class AccountProfileHeaderView: NSView {

    var onHeaderAction: (() -> Void)?

    private let background = WelcomeShellCardView()
    private let avatarView = ImageView()
    private let nameLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 19, weight: .semibold),
        color: .labelColor
    )
    private let userNameLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 12),
        color: .secondaryLabelColor
    )
    private let userIdLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .tertiaryLabelColor
    )
    private let emailLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 12),
        color: .labelColor
    )
    private let verificationLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11, weight: .medium),
        color: .secondaryLabelColor
    )
    private let memberLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor
    )
    private let actionButton = WelcomeShellClosureButton()
    private let textStack = NSStackView()

    private var isLoggedIn = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(background)
        background.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        avatarView.setScaling(.aspectFit)
        avatarView.wantsLayer = true
        avatarView.layer?.cornerRadius = 32
        avatarView.layer?.cornerCurve = .continuous
        avatarView.layer?.masksToBounds = true
        avatarView.layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.12).cgColor
        avatarView.contentTintColor = .mainColor

        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.detachesHiddenViews = true
        [
            nameLabel,
            userNameLabel,
            userIdLabel,
            emailLabel,
            verificationLabel,
            memberLabel
        ].forEach { textStack.addArrangedSubview($0) }

        actionButton.bezelStyle = .rounded
        actionButton.controlSize = .regular
        actionButton.onClick = { [weak self] in
            self?.onHeaderAction?()
        }
        actionButton.setAccessibilityIdentifier(AccessibilityID.Account.headerAction)

        addSubview(avatarView)
        addSubview(textStack)
        addSubview(actionButton)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.top.equalToSuperview().offset(18)
            make.width.height.equalTo(64)
        }
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(14)
            make.top.equalToSuperview().offset(17)
            make.trailing.lessThanOrEqualTo(actionButton.snp.leading).offset(-12)
            make.bottom.equalToSuperview().offset(-18)
        }
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(18)
            make.width.equalTo(112)
        }
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(100)
        }

        setAccessibilityIdentifier(AccessibilityID.Account.header)
        update(isLoggedIn: false, profile: nil, isRefreshing: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(isLoggedIn: Bool, profile: OAuthUserProfile?, isRefreshing: Bool) {
        self.isLoggedIn = isLoggedIn

        if isLoggedIn {
            actionButton.title = NSLocalizedString("刷新", comment: "")
            actionButton.isEnabled = !isRefreshing
            actionButton.setAccessibilityLabel(NSLocalizedString("刷新账号资料", comment: ""))
            actionButton.toolTip = NSLocalizedString("刷新账号资料", comment: "")
        } else {
            actionButton.title = NSLocalizedString("登录弹弹play", comment: "")
            actionButton.isEnabled = true
            actionButton.setAccessibilityLabel(NSLocalizedString("登录弹弹play", comment: ""))
            actionButton.toolTip = NSLocalizedString("登录弹弹play", comment: "")
        }

        guard isLoggedIn else {
            nameLabel.text = NSLocalizedString("未登录", comment: "")
            userNameLabel.isHidden = true
            userIdLabel.isHidden = true
            emailLabel.isHidden = true
            verificationLabel.isHidden = true
            memberLabel.isHidden = true
            avatarView.kf.cancelDownloadTask()
            avatarView.image = welcomeShellSymbol("person.crop.circle.fill", pointSize: 58, weight: .regular)
            avatarView.contentTintColor = .mainColor
            setAccessibilityLabel(NSLocalizedString("未登录", comment: ""))
            return
        }

        nameLabel.text = profile?.displayName ?? NSLocalizedString("已登录用户", comment: "")

        if let userName = profile?.userName, !userName.isEmpty {
            userNameLabel.text = "@\(userName)"
            userNameLabel.isHidden = false
        } else {
            userNameLabel.isHidden = true
        }

        if let userId = profile?.userId, userId > 0 {
            userIdLabel.text = String(format: NSLocalizedString("用户 ID：%d", comment: ""), userId)
            userIdLabel.isHidden = false
        } else {
            userIdLabel.isHidden = true
        }

        if let email = profile?.email, !email.isEmpty {
            emailLabel.text = email
            emailLabel.textColor = .labelColor
            emailLabel.isHidden = false
            verificationLabel.text = profile?.emailVerified == true
                ? NSLocalizedString("邮箱已验证", comment: "")
                : NSLocalizedString("邮箱未验证", comment: "")
            verificationLabel.textColor = profile?.emailVerified == true ? .systemGreen : .systemOrange
            verificationLabel.isHidden = false
        } else {
            emailLabel.text = NSLocalizedString("未设置邮箱", comment: "")
            emailLabel.textColor = .secondaryLabelColor
            emailLabel.isHidden = false
            verificationLabel.isHidden = true
        }

        if let memberDate = profile?.privileges?.member {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if memberDate > Date() {
                memberLabel.text = String(
                    format: NSLocalizedString("会员有效期至 %@", comment: ""),
                    formatter.string(from: memberDate)
                )
                memberLabel.textColor = .mainColor
            } else {
                memberLabel.text = String(
                    format: NSLocalizedString("会员已过期（%@）", comment: ""),
                    formatter.string(from: memberDate)
                )
                memberLabel.textColor = .secondaryLabelColor
            }
        } else {
            memberLabel.text = NSLocalizedString("未开通会员", comment: "")
            memberLabel.textColor = .secondaryLabelColor
        }
        memberLabel.isHidden = false

        if let urlString = profile?.profileImage, !urlString.isEmpty, let url = URL(string: urlString) {
            avatarView.contentTintColor = nil
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.kf.cancelDownloadTask()
            avatarView.image = welcomeShellSymbol("person.crop.circle.fill", pointSize: 58, weight: .regular)
            avatarView.contentTintColor = .mainColor
        }

        setAccessibilityLabel([
            nameLabel.text ?? "",
            userNameLabel.isHidden ? "" : (userNameLabel.text ?? ""),
            emailLabel.text ?? ""
        ].filter { !$0.isEmpty }.joined(separator: "，"))
    }
}

// MARK: - Settings row

final class AccountSettingsRowView: WelcomeShellTapView {

    private let iconView = ImageView()
    private let titleLabel: Label
    private let subtitleLabel: Label
    private let chevron = ImageView()

    init(
        title: String,
        subtitle: String,
        symbolName: String,
        identifier: String,
        destructive: Bool = false
    ) {
        self.titleLabel = welcomeShellLabel(
            title,
            font: .systemFont(ofSize: 13.5, weight: .semibold),
            color: destructive ? .systemRed : .labelColor
        )
        self.subtitleLabel = welcomeShellLabel(
            subtitle,
            font: .systemFont(ofSize: 10.5),
            color: .secondaryLabelColor
        )
        super.init(frame: .zero)

        normalBackgroundProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.55)
        }
        borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.35)
        }
        layer?.cornerRadius = 10
        layer?.borderWidth = 1

        iconView.image = welcomeShellSymbol(symbolName, pointSize: 18, weight: .medium)
        iconView.contentTintColor = destructive ? .systemRed : .mainColor
        iconView.setScaling(.aspectFit)

        chevron.image = welcomeShellSymbol("chevron.right", pointSize: 10, weight: .semibold)
        chevron.contentTintColor = .tertiaryLabelColor
        chevron.setScaling(.aspectFit)

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(chevron)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-10)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(3)
            make.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-10)
            make.bottom.equalToSuperview().offset(-12)
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(12)
        }
        snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        setAccessibilityIdentifier(identifier)
        setAccessibilityLabel("\(title)，\(subtitle)")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setEnabled(_ enabled: Bool) {
        isTapEnabled = enabled
        alphaValue = enabled ? 1 : 0.5
    }
}

// MARK: - bangumi.tv link

final class AccountBangumiCardView: NSView {

    var onAuthorize: (() -> Void)?
    var onManage: (() -> Void)?
    var onRefresh: (() -> Void)?

    private let background = WelcomeShellCardView()
    private let avatarView = ImageView()
    private let titleLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 14, weight: .semibold),
        color: .labelColor
    )
    private let userNameLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor
    )
    private let statusLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor,
        lines: 2,
        lineBreakMode: .byWordWrapping
    )
    private let expiresLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 10.5),
        color: .tertiaryLabelColor,
        lines: 2,
        lineBreakMode: .byWordWrapping
    )
    private let textStack = NSStackView()
    private let buttonStack = NSStackView()
    private let authorizeButton = AccountBangumiCardView.makeLinkButton()
    private let manageButton = AccountBangumiCardView.makeLinkButton()
    private let refreshButton = AccountBangumiCardView.makeLinkButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(background)
        background.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        avatarView.setScaling(.aspectFit)
        avatarView.wantsLayer = true
        avatarView.layer?.cornerRadius = 22
        avatarView.layer?.cornerCurve = .continuous
        avatarView.layer?.masksToBounds = true
        avatarView.layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.10).cgColor
        avatarView.contentTintColor = .mainColor

        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.detachesHiddenViews = true
        [titleLabel, userNameLabel, statusLabel, expiresLabel].forEach {
            textStack.addArrangedSubview($0)
        }

        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 14
        buttonStack.detachesHiddenViews = true
        authorizeButton.title = NSLocalizedString("去授权", comment: "")
        authorizeButton.onClick = { [weak self] in self?.onAuthorize?() }
        authorizeButton.setAccessibilityIdentifier(AccessibilityID.Account.bangumiAuthorize)
        manageButton.title = NSLocalizedString("管理关联", comment: "")
        manageButton.onClick = { [weak self] in self?.onManage?() }
        manageButton.setAccessibilityIdentifier(AccessibilityID.Account.bangumiManage)
        refreshButton.title = NSLocalizedString("刷新状态", comment: "")
        refreshButton.onClick = { [weak self] in self?.onRefresh?() }
        refreshButton.setAccessibilityIdentifier(AccessibilityID.Account.bangumiRefresh)
        [authorizeButton, manageButton, refreshButton].forEach { buttonStack.addArrangedSubview($0) }

        addSubview(avatarView)
        addSubview(textStack)
        addSubview(buttonStack)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(16)
            make.width.height.equalTo(44)
        }
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-16)
        }
        buttonStack.snp.makeConstraints { make in
            make.leading.equalTo(textStack)
            make.top.equalTo(textStack.snp.bottom).offset(12)
            make.bottom.equalToSuperview().offset(-16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
        avatarView.snp.makeConstraints { make in
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }

        setAccessibilityIdentifier(AccessibilityID.Account.bangumiCard)
        update(state: AccountBangumiLinkState(account: nil), isBusy: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(state: AccountBangumiLinkState, isBusy: Bool) {
        authorizeButton.isEnabled = !isBusy
        manageButton.isEnabled = !isBusy
        refreshButton.isEnabled = !isBusy

        switch state.status {
        case .notLinked:
            avatarView.isHidden = true
            titleLabel.text = NSLocalizedString("尚未关联 bangumi.tv", comment: "")
            userNameLabel.isHidden = true
            statusLabel.text = NSLocalizedString("关联后可在后台自动同步观看进度", comment: "")
            statusLabel.textColor = .secondaryLabelColor
            expiresLabel.isHidden = true
            authorizeButton.isHidden = false
            manageButton.isHidden = true
            refreshButton.isHidden = true
        case .linked, .expired:
            let account = state.account
            avatarView.isHidden = false
            titleLabel.text = account?.displayName ?? NSLocalizedString("bangumi.tv 用户", comment: "")

            if let userName = account?.userName, !userName.isEmpty {
                userNameLabel.text = "@\(userName)"
                userNameLabel.isHidden = false
            } else {
                userNameLabel.isHidden = true
            }

            if state.status == .expired {
                statusLabel.text = NSLocalizedString("授权已过期，请重新授权", comment: "")
                statusLabel.textColor = .systemOrange
                authorizeButton.isHidden = false
                manageButton.isHidden = false
            } else {
                statusLabel.text = NSLocalizedString("已关联 bangumi.tv", comment: "")
                statusLabel.textColor = .secondaryLabelColor
                authorizeButton.isHidden = true
                manageButton.isHidden = false
            }

            if let expires = account?.expires {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                expiresLabel.text = String(
                    format: NSLocalizedString("授权有效期至 %@", comment: ""),
                    formatter.string(from: expires)
                )
                expiresLabel.isHidden = false
            } else {
                expiresLabel.isHidden = true
            }
            refreshButton.isHidden = false

            if let avatarURL = account?.avatar, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                avatarView.contentTintColor = nil
                avatarView.kf.setImage(with: url)
            } else {
                avatarView.kf.cancelDownloadTask()
                avatarView.image = welcomeShellSymbol("person.crop.circle.fill", pointSize: 38)
                avatarView.contentTintColor = .mainColor
            }
        }

        setAccessibilityLabel([
            titleLabel.text ?? "",
            statusLabel.text ?? "",
            expiresLabel.isHidden ? "" : (expiresLabel.text ?? "")
        ].filter { !$0.isEmpty }.joined(separator: "，"))
    }

    private static func makeLinkButton() -> WelcomeShellClosureButton {
        let button = WelcomeShellClosureButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.contentTintColor = .mainColor
        button.controlSize = .small
        return button
    }
}
