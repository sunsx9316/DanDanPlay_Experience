//
//  MainAccountHubViewController.swift
//  AniXPlayer
//
//  macOS：主窗口「我的」页（账号、会员与常用功能入口）。
//

import Cocoa
import SnapKit
import Kingfisher

// MARK: - User card

private final class MainAccountUserCardView: NSView {

    var onLogin: (() -> Void)?
    var onShowMembership: (() -> Void)?
    var onShowProfile: (() -> Void)?

    private let background = WelcomeShellCardView()
    private let avatarView = ImageView()
    private let nameLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 18, weight: .semibold),
        color: .labelColor
    )
    private let statusLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11.5),
        color: .secondaryLabelColor
    )
    private let detailLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 10.5),
        color: .tertiaryLabelColor
    )
    private let actionStack = NSStackView()
    private let profileButton = WelcomeShellClosureButton()
    private let actionButton = WelcomeShellClosureButton()
    private var isLoggedIn = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(background)
        background.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        avatarView.setScaling(.aspectFit)
        avatarView.wantsLayer = true
        avatarView.layer?.cornerRadius = 24
        avatarView.layer?.masksToBounds = true
        avatarView.layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.14).cgColor
        avatarView.contentTintColor = .mainColor

        actionButton.bezelStyle = .rounded
        actionButton.controlSize = .regular
        actionButton.onClick = { [weak self] in
            guard let self = self else { return }
            if self.isLoggedIn {
                self.onShowMembership?()
            } else {
                self.onLogin?()
            }
        }
        actionButton.setAccessibilityIdentifier(
            "\(AccessibilityID.MainShell.accountCardPrefix)profileAction"
        )

        profileButton.bezelStyle = .rounded
        profileButton.controlSize = .regular
        profileButton.title = NSLocalizedString("账号资料", comment: "")
        profileButton.onClick = { [weak self] in
            self?.onShowProfile?()
        }
        profileButton.setAccessibilityIdentifier(AccessibilityID.Account.openButton)
        profileButton.setAccessibilityLabel(NSLocalizedString("账号资料", comment: ""))

        actionStack.orientation = .vertical
        actionStack.alignment = .trailing
        actionStack.spacing = 6
        actionStack.detachesHiddenViews = true
        actionStack.addArrangedSubview(profileButton)
        actionStack.addArrangedSubview(actionButton)
        profileButton.snp.makeConstraints { make in
            make.width.equalTo(108)
        }
        actionButton.snp.makeConstraints { make in
            make.width.equalTo(108)
        }

        addSubview(avatarView)
        addSubview(nameLabel)
        addSubview(statusLabel)
        addSubview(detailLabel)
        addSubview(actionStack)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(14)
            make.top.equalToSuperview().offset(18)
            make.trailing.lessThanOrEqualTo(actionStack.snp.leading).offset(-14)
        }
        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.trailing.lessThanOrEqualTo(actionStack.snp.leading).offset(-14)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(statusLabel.snp.bottom).offset(2)
            make.trailing.lessThanOrEqualTo(actionStack.snp.leading).offset(-14)
        }
        actionStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-18)
            make.centerY.equalToSuperview()
        }
        snp.makeConstraints { make in
            make.height.equalTo(100)
        }

        setAccessibilityIdentifier("\(AccessibilityID.MainShell.accountCardPrefix)profile")
        update(isLoggedIn: false, profile: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(isLoggedIn: Bool, profile: OAuthUserProfile?) {
        self.isLoggedIn = isLoggedIn

        guard isLoggedIn else {
            nameLabel.text = NSLocalizedString("未登录", comment: "")
            statusLabel.text = NSLocalizedString("登录后同步追番、播放历史与会员权益", comment: "")
            statusLabel.textColor = .secondaryLabelColor
            detailLabel.text = ""
            detailLabel.isHidden = true
            profileButton.isHidden = false
            actionButton.title = NSLocalizedString("登录弹弹play", comment: "")
            avatarView.kf.cancelDownloadTask()
            avatarView.image = welcomeShellSymbol("person.crop.circle.fill", pointSize: 44, weight: .regular)
            avatarView.contentTintColor = .mainColor
            setAccessibilityLabel(NSLocalizedString("未登录", comment: ""))
            return
        }

        nameLabel.text = profile?.displayName ?? NSLocalizedString("已登录用户", comment: "")
        profileButton.isHidden = false

        if let memberDate = profile?.privileges?.member, memberDate > Date() {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            statusLabel.text = String(
                format: NSLocalizedString("会员有效期至 %@", comment: ""),
                formatter.string(from: memberDate)
            )
            statusLabel.textColor = .mainColor
        } else {
            statusLabel.text = NSLocalizedString("未开通会员", comment: "")
            statusLabel.textColor = .secondaryLabelColor
        }

        let userName = profile?.userName ?? ""
        detailLabel.text = userName.isEmpty ? NSLocalizedString("已登录", comment: "") : "@\(userName)"
        detailLabel.isHidden = false
        actionButton.title = NSLocalizedString("会员中心", comment: "")

        if let urlString = profile?.profileImage, !urlString.isEmpty, let url = URL(string: urlString) {
            avatarView.contentTintColor = nil
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.kf.cancelDownloadTask()
            avatarView.image = welcomeShellSymbol("person.crop.circle.fill", pointSize: 44, weight: .regular)
            avatarView.contentTintColor = .mainColor
        }

        setAccessibilityLabel(
            "\(nameLabel.text ?? "")，\(statusLabel.text ?? "")"
        )
    }
}

// MARK: - Shortcut card

private final class MainAccountCardView: WelcomeShellTapView {

    init(key: String, title: String, subtitle: String, symbolName: String) {
        super.init(frame: .zero)

        normalBackgroundProvider = {
            NSColor.controlBackgroundColor.withAlphaComponent(0.55)
        }
        borderColorProvider = {
            NSColor.separatorColor.withAlphaComponent(0.35)
        }
        layer?.cornerRadius = 10
        layer?.borderWidth = 1

        let iconView = ImageView()
        iconView.image = welcomeShellSymbol(symbolName, pointSize: 20, weight: .medium)
        iconView.contentTintColor = .mainColor
        iconView.setScaling(.aspectFit)

        let titleLabel = welcomeShellLabel(
            title,
            font: .systemFont(ofSize: 13.5, weight: .semibold),
            color: .labelColor
        )
        let subtitleLabel = welcomeShellLabel(
            subtitle,
            font: .systemFont(ofSize: 10.5),
            color: .secondaryLabelColor
        )
        let chevron = ImageView()
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
            make.width.height.equalTo(26)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(17)
            make.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-8)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(3)
            make.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-8)
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(12)
        }
        snp.makeConstraints { make in
            make.height.equalTo(82)
        }

        setAccessibilityIdentifier("\(AccessibilityID.MainShell.accountCardPrefix)\(key)")
        setAccessibilityLabel([title, subtitle].joined(separator: "，"))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Responsive card grid

private final class MainAccountCardGridView: NSView {

    struct Item {
        let key: String
        let title: String
        let subtitle: String
        let symbolName: String
    }

    var onSelect: ((String) -> Void)?
    var onHeightChange: (() -> Void)?

    private let rowStack = NSStackView()
    private var items: [Item] = []
    private var lastWidth: CGFloat = 0
    private var lastColumns = 0
    private var heightConstraint: Constraint?
    private let spacing: CGFloat = 12

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        rowStack.orientation = .vertical
        rowStack.alignment = .width
        rowStack.spacing = spacing
        addSubview(rowStack)
        rowStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        snp.makeConstraints { make in
            heightConstraint = make.height.equalTo(0).constraint
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        rebuildIfNeeded()
    }

    func reload(items: [Item]) {
        self.items = items
        lastWidth = 0
        lastColumns = 0
        rebuildIfNeeded()
    }

    private func rebuildIfNeeded() {
        let width = bounds.width
        guard width > 1 else { return }

        let columns = width < 620 ? 1 : 2
        guard width != lastWidth || columns != lastColumns else { return }
        lastWidth = width
        lastColumns = columns

        rowStack.arrangedSubviews.forEach {
            rowStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        var index = 0
        while index < items.count {
            let upper = min(index + columns, items.count)
            let rowItems = Array(items[index..<upper])
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.distribution = .fillEqually
            row.spacing = spacing

            for item in rowItems {
                let card = MainAccountCardView(
                    key: item.key,
                    title: item.title,
                    subtitle: item.subtitle,
                    symbolName: item.symbolName
                )
                card.onClick = { [weak self] in
                    self?.onSelect?(item.key)
                }
                row.addArrangedSubview(card)
                card.snp.makeConstraints { make in
                    make.height.equalTo(82)
                }
            }

            if columns == 2, rowItems.count < columns {
                let spacer = NSView()
                row.addArrangedSubview(spacer)
                spacer.snp.makeConstraints { make in
                    make.height.equalTo(82)
                }
            }

            rowStack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.width.equalTo(rowStack)
            }
            index = upper
        }

        let rowCount = Int(ceil(Double(items.count) / Double(columns)))
        let height = CGFloat(max(0, rowCount)) * 82 + CGFloat(max(0, rowCount - 1)) * spacing
        heightConstraint?.update(offset: height)
        invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in
            self?.onHeightChange?()
        }
    }
}

// MARK: - Account hub

final class MainAccountHubViewController: WelcomeShellScrollPageViewController {

    var onShowHistory: (() -> Void)?
    var onShowMembership: (() -> Void)?
    var onShowSettings: (() -> Void)?

    private let userCard = MainAccountUserCardView()
    private let cardGrid = MainAccountCardGridView()

    private lazy var items: [MainAccountCardGridView.Item] = [
        .init(
            key: "queue",
            title: NSLocalizedString("我的追番", comment: ""),
            subtitle: NSLocalizedString("追番队列与未看剧集", comment: ""),
            symbolName: "tv"
        ),
        .init(
            key: "history",
            title: NSLocalizedString("播放历史", comment: ""),
            subtitle: NSLocalizedString("继续上次的观看进度", comment: ""),
            symbolName: "clock.arrow.circlepath"
        ),
        .init(
            key: "membership",
            title: NSLocalizedString("会员中心", comment: ""),
            subtitle: NSLocalizedString("会员权益与订单", comment: ""),
            symbolName: "crown"
        ),
        .init(
            key: "settings",
            title: NSLocalizedString("全局设置", comment: ""),
            subtitle: NSLocalizedString("外观、播放与网络", comment: ""),
            symbolName: "gearshape"
        ),
        .init(
            key: "translation",
            title: NSLocalizedString("翻译字幕", comment: ""),
            subtitle: NSLocalizedString("批量翻译字幕文件", comment: ""),
            symbolName: "character.book.closed"
        ),
        .init(
            key: "summary",
            title: NSLocalizedString("AI 视频总结", comment: ""),
            subtitle: NSLocalizedString("用 AI 生成本集摘要", comment: ""),
            symbolName: "sparkles"
        ),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("我的", comment: "")

        let header = WelcomeShellPageHeaderView(
            title: NSLocalizedString("我的", comment: ""),
            subtitle: NSLocalizedString("账号、会员与常用功能", comment: "")
        )
        addFullWidth(header, spacingAfter: 2)
        addFullWidth(userCard)

        let sectionLabel = welcomeShellLabel(
            NSLocalizedString("快捷入口", comment: ""),
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .secondaryLabelColor
        )
        addFullWidth(sectionLabel, spacingAfter: 0)
        addFullWidth(cardGrid)

        userCard.onLogin = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                _ = await LoginGate.shared.ensureLoggedIn(presenting: self.view.window)
                self.refreshSession()
            }
        }
        userCard.onShowMembership = { [weak self] in
            self?.onShowMembership?()
        }
        userCard.onShowProfile = { [weak self] in
            guard let self = self else { return }
            MacFeatureLauncher.showAccountProfile(presenting: self.view.window)
        }

        cardGrid.onSelect = { [weak self] key in
            self?.handleCard(key)
        }
        cardGrid.onHeightChange = { [weak self] in
            self?.layoutContent()
        }
        cardGrid.reload(items: items)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loginStateChanged),
            name: .AnixUserLoginStateDidChange,
            object: nil
        )
        refreshSession()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshSession()
    }

    func updateSession(isLoggedIn: Bool, profile: OAuthUserProfile?) {
        userCard.update(isLoggedIn: isLoggedIn, profile: profile)
    }

    func refreshSession() {
        let session = SessionStore.shared
        Task { @MainActor [weak self] in
            let loggedIn = await session.isLoggedIn()
            let profile = await session.currentProfile()
            self?.updateSession(isLoggedIn: loggedIn, profile: profile)
        }
    }

    @objc private func loginStateChanged() {
        refreshSession()
    }

    private func handleCard(_ key: String) {
        switch key {
        case "queue":
            WelcomeQueueWindowPresenter.shared.open(presenting: view.window)
        case "history":
            onShowHistory?()
        case "membership":
            onShowMembership?()
        case "settings":
            onShowSettings?()
        case "translation":
            MacFeatureLauncher.showTranslation(presenting: view.window)
        case "summary":
            MacFeatureLauncher.showSummary(presenting: view.window)
        default:
            break
        }
    }
}
