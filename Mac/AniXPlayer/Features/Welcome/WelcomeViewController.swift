//
//  WelcomeViewController.swift
//  AniXPlayer
//
//  macOS 欢迎页：品牌区、本地播放 / 拖拽、快捷入口、最近播放与能力介绍。
//

import Cocoa
import SnapKit
import ANXLog
import UniformTypeIdentifiers

// MARK: - WelcomeViewController

final class WelcomeViewController: ViewController {

    // MARK: Callbacks

    var onOpenFiles: (([File], File?) -> Void)?
    var onOpenNetworkFile: (() -> Void)?
    var onShowHomePage: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowMembership: (() -> Void)? {
        didSet {
            updateMembershipAvailability()
        }
    }

    // MARK: Data

    private let recentStore = WelcomeRecentStore.shared

    private var recentItems: [WelcomeRecentItem] {
        return recentStore.items
    }

    private var didApplyWindowMinimum = false

    // MARK: Header

    private lazy var appIconView: ImageView = {
        let view = ImageView()
        view.image = NSApplication.shared.applicationIconImage
        view.setScaling(.aspectFit)
        return view
    }()

    private lazy var brandTitleLabel: Label = {
        return welcomeLabel(brandName, font: .systemFont(ofSize: 26, weight: .bold), color: .labelColor)
    }()

    private lazy var versionLabel: Label = {
        return welcomeLabel(versionText, font: .systemFont(ofSize: 11, weight: .medium), color: .secondaryLabelColor)
    }()

    private lazy var sloganLabel: Label = {
        return welcomeLabel(
            NSLocalizedString("本地播放 · 弹幕 · AI 总结", comment: ""),
            font: .ddp_small(weight: .medium),
            color: .secondaryLabelColor
        )
    }()

    // MARK: Hero / drag area

    private lazy var dropView: WelcomeDropView = {
        let view = WelcomeDropView()
        view.setAccessibilityIdentifier(AccessibilityID.Launch.dragArea)
        view.setAccessibilityLabel(NSLocalizedString("拖入视频或文件夹", comment: ""))
        view.dragFilesCallBack = { [weak self] files in
            guard let self = self else { return }

            let mediaFiles = files.filter { !$0.url.isSubtitleFile && !$0.url.isDanmakuFile }
            guard !mediaFiles.isEmpty else {
                self.view.show(text: NSLocalizedString("请先打开视频文件", comment: ""))
                return
            }
            self.onOpenFiles?(mediaFiles, nil)
        }
        return view
    }()

    private lazy var heroIconBadge: WelcomeIconBadge = {
        return WelcomeIconBadge(symbolName: "play.rectangle.fill", size: 76, symbolSize: 34)
    }()

    private lazy var heroTitleLabel: Label = {
        return welcomeLabel(
            NSLocalizedString("打开本地视频", comment: ""),
            font: .systemFont(ofSize: 21, weight: .semibold),
            color: .labelColor
        )
    }()

    private lazy var heroHintLabel: Label = {
        return welcomeLabel(
            NSLocalizedString("选择文件，或把视频 / 文件夹拖到这里", comment: ""),
            font: .ddp_small(),
            color: .secondaryLabelColor
        )
    }()

    private lazy var openButton: WelcomePrimaryButton = {
        let button = WelcomePrimaryButton(
            title: NSLocalizedString("打开本地文件", comment: ""),
            symbolName: "folder.fill"
        )
        button.target = self
        button.action = #selector(openLocalFile)
        button.setAccessibilityIdentifier(AccessibilityID.Launch.openButton)
        button.setAccessibilityLabel(NSLocalizedString("打开或拖入文件", comment: ""))
        return button
    }()

    private lazy var formatLabel: Label = {
        return welcomeLabel(
            NSLocalizedString("支持 MP4 · MKV · AVI · MOV 等常见格式", comment: ""),
            font: .systemFont(ofSize: 11),
            color: .tertiaryLabelColor
        )
    }()

    // MARK: Recent playback

    private lazy var recentCard: WelcomeCard = {
        return WelcomeCard(style: .standard)
    }()

    private lazy var recentHeaderLabel: Label = {
        let label = welcomeLabel(
            NSLocalizedString("最近播放", comment: ""),
            font: .ddp_normal(weight: .semibold),
            color: .labelColor
        )
        label.setAccessibilityIdentifier(AccessibilityID.Launch.recentHeader)
        return label
    }()

    private lazy var clearRecentButton: Button = {
        let button = Button.custom()
        button.attributedTitle = NSAttributedString(
            string: NSLocalizedString("清空", comment: ""),
            attributes: [
                .font: NSFont.ddp_small(),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        button.target = self
        button.action = #selector(clearRecentPlayback)
        button.setAccessibilityIdentifier(AccessibilityID.Launch.recentClear)
        button.setAccessibilityLabel(NSLocalizedString("清空最近播放", comment: ""))
        return button
    }()

    private lazy var recentListStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 6
        stack.setAccessibilityIdentifier(AccessibilityID.Launch.recentList)
        stack.setAccessibilityLabel(NSLocalizedString("最近播放列表", comment: ""))
        return stack
    }()

    private lazy var recentEmptyView: NSView = {
        let container = NSView()

        let icon = WelcomeIconBadge(symbolName: "clock.arrow.circlepath", size: 54, symbolSize: 24)
        let title = welcomeLabel(
            NSLocalizedString("还没有播放记录", comment: ""),
            font: .ddp_small(weight: .semibold),
            color: .secondaryLabelColor
        )
        let detail = welcomeLabel(
            NSLocalizedString("打开视频后，这里会显示最近播放与进度", comment: ""),
            font: .systemFont(ofSize: 11),
            color: .tertiaryLabelColor,
            alignment: .center
        )
        detail.maximumNumberOfLines = 2
        detail.cell?.wraps = true
        detail.cell?.isScrollable = false

        let stack = NSStackView(views: [icon, title, detail])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(12, after: icon)

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }

        container.setAccessibilityIdentifier(AccessibilityID.Launch.recentEmpty)
        return container
    }()

    // MARK: Quick actions

    private lazy var networkButton: WelcomeQuickButton = {
        let button = WelcomeQuickButton(
            title: NSLocalizedString("网络文件", comment: ""),
            symbolName: "network"
        )
        button.target = self
        button.action = #selector(openNetworkFile)
        button.setAccessibilityIdentifier(AccessibilityID.Launch.networkButton)
        button.setAccessibilityLabel(NSLocalizedString("打开网络文件", comment: ""))
        return button
    }()

    private lazy var homeButton: WelcomeQuickButton = {
        let button = WelcomeQuickButton(
            title: NSLocalizedString("主页", comment: ""),
            symbolName: "house.fill"
        )
        button.target = self
        button.action = #selector(openHomePage)
        button.setAccessibilityIdentifier(AccessibilityID.Launch.homeButton)
        button.setAccessibilityLabel(NSLocalizedString("打开主页", comment: ""))
        return button
    }()

    private lazy var settingsButton: WelcomeQuickButton = {
        let button = WelcomeQuickButton(
            title: NSLocalizedString("全局设置", comment: ""),
            symbolName: "gearshape.fill"
        )
        button.target = self
        button.action = #selector(openSettings)
        button.setAccessibilityIdentifier(AccessibilityID.Launch.settingsButton)
        button.setAccessibilityLabel(NSLocalizedString("打开全局设置", comment: ""))
        return button
    }()

    private lazy var membershipButton: WelcomeQuickButton = {
        let button = WelcomeQuickButton(
            title: NSLocalizedString("会员中心", comment: ""),
            symbolName: "crown.fill"
        )
        button.target = self
        button.action = #selector(openMembership)
        button.setAccessibilityIdentifier(AccessibilityID.Launch.membershipButton)
        button.setAccessibilityLabel(NSLocalizedString("打开会员中心", comment: ""))
        return button
    }()

    private lazy var quickStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.setAccessibilityIdentifier(AccessibilityID.Launch.quickActions)
        stack.addArrangedSubview(networkButton)
        stack.addArrangedSubview(homeButton)
        stack.addArrangedSubview(settingsButton)
        stack.addArrangedSubview(membershipButton)

        [networkButton, homeButton, settingsButton, membershipButton].forEach { button in
            button.snp.makeConstraints { make in
                make.height.equalTo(stack)
            }
        }
        return stack
    }()

    // MARK: Feature cards

    private lazy var featureStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.setAccessibilityIdentifier(AccessibilityID.Launch.featureArea)

        let danmakuCard = makeFeatureCard(
            title: NSLocalizedString("弹幕匹配", comment: ""),
            detail: NSLocalizedString("自动加载与匹配弹幕", comment: ""),
            symbolName: "text.bubble.fill",
            identifier: AccessibilityID.Launch.featureDanmaku,
            badge: nil
        )
        let summaryCard = makeFeatureCard(
            title: NSLocalizedString("AI 视频总结", comment: ""),
            detail: NSLocalizedString("剧情摘要与关键看点", comment: ""),
            symbolName: "sparkles",
            identifier: AccessibilityID.Launch.featureSummary,
            badge: NSLocalizedString("会员", comment: "")
        )
        let membershipCard = makeFeatureCard(
            title: NSLocalizedString("会员补充弹幕", comment: ""),
            detail: NSLocalizedString("会员专属与云端同步", comment: ""),
            symbolName: "crown.fill",
            identifier: AccessibilityID.Launch.featureMembership,
            badge: NSLocalizedString("会员", comment: "")
        )

        [danmakuCard, summaryCard, membershipCard].forEach { card in
            stack.addArrangedSubview(card)
            card.snp.makeConstraints { make in
                make.height.equalTo(stack)
            }
        }
        return stack
    }()

    // MARK: - Lifecycle

    override func loadView() {
        let rootView = WelcomeRootView(frame: .init(x: 0, y: 0, width: 800, height: 600))
        rootView.onAppearanceChange = { [weak self] in
            self?.updateBackgroundColor()
        }
        self.view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = AppInfoHelper.appDisplayName
        self.view.wantsLayer = true
        self.view.setAccessibilityIdentifier(AccessibilityID.Launch.root)
        updateBackgroundColor()

        setupUI()
        reloadRecentPlayback()
        updateMembershipAvailability()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recentPlaybackDidChange),
            name: .welcomeRecentPlaybackDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        reloadRecentPlayback()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        guard !didApplyWindowMinimum, let window = self.view.window else { return }
        didApplyWindowMinimum = true

        window.contentMinSize = NSSize(width: 800, height: 600)
        let contentSize = window.contentLayoutRect.size
        if contentSize.width < 800 || contentSize.height < 600 {
            window.setContentSize(NSSize(width: max(contentSize.width, 800),
                                         height: max(contentSize.height, 600)))
        }
    }

    // MARK: - Public

    func presentLocalFilePicker() {
        openLocalFile()
    }

    // MARK: - Setup

    private func setupUI() {
        let headerView = makeHeaderView()
        let middleView = NSView()

        self.view.addSubview(headerView)
        self.view.addSubview(middleView)
        self.view.addSubview(featureStack)
        self.view.addSubview(quickStack)

        headerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(28)
            make.height.equalTo(56)
        }

        quickStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(28)
            make.bottom.equalToSuperview().offset(-22)
            make.height.equalTo(52)
        }

        featureStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(28)
            make.bottom.equalTo(quickStack.snp.top).offset(-14)
            make.height.equalTo(82)
        }

        middleView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(28)
            make.top.equalTo(headerView.snp.bottom).offset(18)
            make.bottom.equalTo(featureStack.snp.top).offset(-16)
        }

        setupDropArea(in: middleView)
        setupRecentCard(in: middleView)
    }

    private func makeHeaderView() -> NSView {
        let header = NSView()

        let titleRow = NSStackView(views: [brandTitleLabel, versionLabel])
        titleRow.orientation = .horizontal
        titleRow.alignment = .firstBaseline
        titleRow.spacing = 8

        let textStack = NSStackView(views: [titleRow, sloganLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3

        let badge = WelcomeOfflineBadge()

        header.addSubview(appIconView)
        header.addSubview(textStack)
        header.addSubview(badge)

        appIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(46)
        }

        textStack.snp.makeConstraints { make in
            make.leading.equalTo(appIconView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(badge.snp.leading).offset(-16)
        }

        badge.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        brandTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return header
    }

    private func setupDropArea(in container: NSView) {
        container.addSubview(dropView)

        let contentStack = NSStackView(views: [
            heroIconBadge,
            heroTitleLabel,
            heroHintLabel,
            openButton,
            formatLabel
        ])
        contentStack.orientation = .vertical
        contentStack.alignment = .centerX
        contentStack.spacing = 0
        contentStack.setCustomSpacing(14, after: heroIconBadge)
        contentStack.setCustomSpacing(5, after: heroTitleLabel)
        contentStack.setCustomSpacing(18, after: heroHintLabel)
        contentStack.setCustomSpacing(13, after: openButton)

        dropView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }

        openButton.snp.makeConstraints { make in
            make.width.equalTo(194)
            make.height.equalTo(44)
        }

        dropView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(container.snp.centerX).offset(-8)
        }
    }

    private func setupRecentCard(in container: NSView) {
        container.addSubview(recentCard)

        let headerIcon = ImageView()
        headerIcon.image = welcomeSymbol("clock.arrow.circlepath", pointSize: 15, weight: .medium)
        headerIcon.contentTintColor = .mainColor
        headerIcon.setScaling(.aspectFit)

        recentCard.addSubview(headerIcon)
        recentCard.addSubview(recentHeaderLabel)
        recentCard.addSubview(clearRecentButton)
        recentCard.addSubview(recentListStack)
        recentCard.addSubview(recentEmptyView)

        headerIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(17)
            make.width.height.equalTo(16)
        }

        recentHeaderLabel.snp.makeConstraints { make in
            make.leading.equalTo(headerIcon.snp.trailing).offset(7)
            make.centerY.equalTo(headerIcon)
            make.trailing.lessThanOrEqualTo(clearRecentButton.snp.leading).offset(-8)
        }

        clearRecentButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(headerIcon)
        }

        recentListStack.snp.makeConstraints { make in
            make.top.equalTo(headerIcon.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }

        recentEmptyView.snp.makeConstraints { make in
            make.top.equalTo(headerIcon.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.equalToSuperview().offset(-12)
        }

        recentCard.snp.makeConstraints { make in
            make.leading.equalTo(container.snp.centerX).offset(8)
            make.trailing.top.bottom.equalToSuperview()
        }
    }

    private func makeFeatureCard(title: String,
                                 detail: String,
                                 symbolName: String,
                                 identifier: String,
                                 badge: String?) -> WelcomeFeatureCard {
        let card = WelcomeFeatureCard(
            title: title,
            detail: detail,
            symbolName: symbolName,
            badge: badge
        )
        card.setAccessibilityIdentifier(identifier)
        card.setAccessibilityElement(true)
        card.setAccessibilityRole(.group)
        card.setAccessibilityLabel("\(title)，\(detail)")
        return card
    }

    // MARK: - Recent playback

    private func reloadRecentPlayback() {
        guard isViewLoaded else { return }

        recentListStack.arrangedSubviews.forEach {
            recentListStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let items = recentItems
        let isEmpty = items.isEmpty
        clearRecentButton.isHidden = isEmpty
        recentEmptyView.isHidden = !isEmpty
        recentListStack.isHidden = isEmpty

        guard !isEmpty else { return }

        for (index, item) in items.enumerated() {
            let row = WelcomeRecentRow(item: item)
            row.tag = index
            row.target = self
            row.action = #selector(recentItemTapped(_:))
            row.setAccessibilityIdentifier("\(AccessibilityID.Launch.recentItemPrefix)\(index)")
            recentListStack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.leading.trailing.equalTo(recentListStack)
                make.height.equalTo(54)
            }
        }
    }

    @objc private func recentPlaybackDidChange() {
        reloadRecentPlayback()
    }

    @objc private func recentItemTapped(_ sender: NSButton) {
        let items = recentItems
        guard sender.tag >= 0, sender.tag < items.count else { return }

        let item = items[sender.tag]
        guard let url = recentStore.resolveURL(for: item) else {
            recentStore.remove(path: item.path)
            self.view.show(text: NSLocalizedString("文件已不存在或无法访问", comment: ""))
            return
        }

        ANX.logInfo(.UI, "[Welcome] 继续播放: \(url.lastPathComponent)")
        let file = LocalFile(with: url)
        let files: [File] = [file]
        self.onOpenFiles?(files, file)
    }

    @objc private func clearRecentPlayback() {
        recentStore.clear()
    }

    // MARK: - Quick actions

    private func updateMembershipAvailability() {
        guard isViewLoaded else { return }

        let isAvailable = onShowMembership != nil
        membershipButton.isEnabled = isAvailable
        membershipButton.alphaValue = isAvailable ? 1 : 0.45
        membershipButton.toolTip = isAvailable ? nil : NSLocalizedString("会员中心即将支持", comment: "")
        membershipButton.refreshAppearance()
    }

    @objc private func openLocalFile() {
        ANX.logInfo(.UI, "[Welcome] 点击打开文件")
        LocalFile.fileManager.pickFiles(LocalFile.rootFile, from: self, filterType: .all) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let files):
                let mediaFiles = files.filter { !$0.url.isSubtitleFile && !$0.url.isDanmakuFile }
                guard !mediaFiles.isEmpty else {
                    self.view.show(text: NSLocalizedString("请先打开视频文件", comment: ""))
                    return
                }
                self.onOpenFiles?(mediaFiles, nil)
            case .failure:
                break
            }
        }
    }

    @objc private func openNetworkFile() {
        ANX.logInfo(.UI, "[Welcome] 点击网络文件")
        onOpenNetworkFile?()
    }

    @objc private func openHomePage() {
        ANX.logInfo(.UI, "[Welcome] 点击主页")
        onShowHomePage?()
    }

    @objc private func openSettings() {
        ANX.logInfo(.UI, "[Welcome] 点击全局设置")
        onShowSettings?()
    }

    @objc private func openMembership() {
        ANX.logInfo(.UI, "[Welcome] 点击会员中心")
        onShowMembership?()
    }

    // MARK: - Appearance

    private func updateBackgroundColor() {
        self.view.effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            self?.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }

    // MARK: - Text

    private var brandName: String {
        let name = AppInfoHelper.appDisplayName
        return name.isEmpty ? "弹弹play" : name
    }

    private var versionText: String {
        let version = AppInfoHelper.appVersion
        return version.isEmpty ? "" : "v\(version)"
    }
}

// MARK: - WelcomeRootView

private final class WelcomeRootView: NSView {

    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}

// MARK: - WelcomeRecentItem / Store

extension Notification.Name {
    static let welcomeRecentPlaybackDidChange = Notification.Name("WelcomeRecentPlaybackDidChange")
}

/// 轻量的最近播放存储（UserDefaults + JSON，不引入数据库）。
/// 使用 security-scoped bookmark，确保 App Sandbox 下重新启动后仍能打开最近文件。
final class WelcomeRecentStore {

    static let shared = WelcomeRecentStore()

    private let defaultsKey = "AniXPlayer.Welcome.RecentPlaybacks"
    private let maximumCount = 10
    private var heldScopedPaths = Set<String>()

    private init() {}

    var items: [WelcomeRecentItem] {
        return loadItems()
    }

    func record(file: File, progress: Double? = nil) {
        guard file is LocalFile else { return }
        guard file.url.isFileURL, file.type == .file else { return }
        guard !file.url.isSubtitleFile, !file.url.isDanmakuFile else { return }
        guard isPlayableMedia(file) else { return }

        // 解析软链后再去重：同一视频可能通过 worktree/sample 软链或真实路径打开。
        let url = file.url.resolvingSymlinksInPath().standardizedFileURL
        let path = url.path
        var currentItems = loadItems()
        let existing = currentItems.first(where: { $0.path == path })

        let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let item = WelcomeRecentItem(
            path: path,
            lastOpened: Date().timeIntervalSince1970,
            progress: progress ?? existing?.progress,
            bookmark: bookmark ?? existing?.bookmark
        )

        currentItems.removeAll(where: { $0.path == path })
        currentItems.insert(item, at: 0)
        if currentItems.count > maximumCount {
            currentItems = Array(currentItems.prefix(maximumCount))
        }

        persist(currentItems)
        NotificationCenter.default.post(name: .welcomeRecentPlaybackDidChange, object: nil)
    }

    func remove(path: String) {
        var currentItems = loadItems()
        currentItems.removeAll(where: { $0.path == path })
        persist(currentItems)
        NotificationCenter.default.post(name: .welcomeRecentPlaybackDidChange, object: nil)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        NotificationCenter.default.post(name: .welcomeRecentPlaybackDidChange, object: nil)
    }

    func resolveURL(for item: WelcomeRecentItem) -> URL? {
        var resolvedURL: URL?

        if let bookmark = item.bookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                resolvedURL = url
                holdSecurityScope(for: url)
            }
        }

        if resolvedURL == nil {
            let url = URL(fileURLWithPath: item.path)
            if FileManager.default.fileExists(atPath: url.path) {
                resolvedURL = url
            }
        }

        guard let url = resolvedURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private func holdSecurityScope(for url: URL) {
        let path = url.path
        guard !heldScopedPaths.contains(path) else { return }
        if url.startAccessingSecurityScopedResource() {
            heldScopedPaths.insert(path)
        }
    }

    private func isPlayableMedia(_ file: File) -> Bool {
        return Self.isPlayablePath(file.url.path)
    }

    private static func isPlayablePath(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        if ext == "mkv" {
            return true
        }
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .audiovisualContent)
    }

    private func loadItems() -> [WelcomeRecentItem] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let items = try? JSONDecoder().decode([WelcomeRecentItem].self, from: data) else {
            return []
        }
        var seen = Set<String>()
        return items
            .filter { Self.isPlayablePath($0.path) }
            .sorted { $0.lastOpened > $1.lastOpened }
            .filter { item in
                let resolved = URL(fileURLWithPath: item.path)
                    .resolvingSymlinksInPath()
                    .standardizedFileURL
                    .path
                return seen.insert(resolved).inserted
            }
    }

    private func persist(_ items: [WelcomeRecentItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

// MARK: - WelcomeCard

private class WelcomeCard: BaseView {

    enum Style {
        case standard
        case hero
    }

    var style: Style {
        didSet { updateColors() }
    }

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.style = .standard
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 16
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
            switch self.style {
            case .standard:
                self.layer?.backgroundColor = base.cgColor
                self.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
            case .hero:
                let tinted = base.blended(withFraction: 0.07, of: NSColor.mainColor) ?? base
                self.layer?.backgroundColor = tinted.cgColor
                self.layer?.borderColor = NSColor.mainColor.withAlphaComponent(0.22).cgColor
            }
        }
    }
}

// MARK: - WelcomeDropView

private final class WelcomeDropView: DragView {

    private let dashedBorderLayer = CAShapeLayer()
    private var isDragActive = false {
        didSet { updateColors() }
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
        layer?.cornerRadius = 18
        layer?.cornerCurve = .continuous

        dashedBorderLayer.fillColor = nil
        dashedBorderLayer.lineWidth = 1.2
        dashedBorderLayer.lineDashPattern = [NSNumber(value: 7), NSNumber(value: 5)]
        layer?.addSublayer(dashedBorderLayer)

        updateColors()
    }

    override func layout() {
        super.layout()
        dashedBorderLayer.frame = bounds
        let rect = bounds.insetBy(dx: 0.6, dy: 0.6)
        dashedBorderLayer.path = CGPath(
            roundedRect: rect,
            cornerWidth: 18,
            cornerHeight: 18,
            transform: nil
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDragActive = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragActive = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        isDragActive = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { isDragActive = false }
        return super.performDragOperation(sender)
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }

            let base = NSColor.controlBackgroundColor
            let tinted = base.blended(
                withFraction: self.isDragActive ? 0.16 : 0.06,
                of: NSColor.mainColor
            ) ?? base
            self.layer?.backgroundColor = tinted.cgColor

            let borderColor = self.isDragActive
                ? NSColor.mainColor
                : NSColor.separatorColor.withAlphaComponent(0.9)
            self.dashedBorderLayer.strokeColor = borderColor.cgColor
            self.dashedBorderLayer.lineWidth = self.isDragActive ? 2 : 1.2
            self.dashedBorderLayer.lineDashPattern = self.isDragActive
                ? nil
                : [NSNumber(value: 7), NSNumber(value: 5)]
        }
    }
}

// MARK: - WelcomeIconBadge

private final class WelcomeIconBadge: BaseView {

    init(symbolName: String, size: CGFloat, symbolSize: CGFloat) {
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = size / 2
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.12).cgColor

        let imageView = ImageView()
        imageView.image = welcomeSymbol(symbolName, pointSize: symbolSize, weight: .medium)
        imageView.contentTintColor = .mainColor
        imageView.setScaling(.aspectFit)
        addSubview(imageView)

        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(symbolSize + 6)
        }

        snp.makeConstraints { make in
            make.width.height.equalTo(size)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - WelcomeOfflineBadge

private final class WelcomeOfflineBadge: BaseView {

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
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.10).cgColor

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 3
        dot.layer?.backgroundColor = NSColor.mainColor.cgColor

        let label = welcomeLabel(
            NSLocalizedString("离线可用", comment: ""),
            font: .systemFont(ofSize: 11, weight: .medium),
            color: .secondaryLabelColor
        )

        addSubview(dot)
        addSubview(label)

        dot.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(6)
        }

        label.snp.makeConstraints { make in
            make.leading.equalTo(dot.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }

        snp.makeConstraints { make in
            make.height.equalTo(24)
        }
    }
}

// MARK: - WelcomePrimaryButton

private final class WelcomePrimaryButton: Button {

    private let iconView = ImageView()
    private let titleLabel = Label(labelWithString: "")

    private var isHovered = false {
        didSet { updateColors() }
    }
    private var isPressed = false {
        didSet { updateColors() }
    }
    private var trackingArea: NSTrackingArea?

    init(title: String, symbolName: String) {
        super.init(frame: .zero)

        isBordered = false
        self.title = ""
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.cornerCurve = .continuous

        iconView.image = welcomeSymbol(symbolName, pointSize: 15, weight: .semibold)
        iconView.contentTintColor = .white
        iconView.setScaling(.aspectFit)

        titleLabel.stringValue = title
        titleLabel.font = .ddp_normal(weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.isSelectable = false

        let contentStack = NSStackView(views: [iconView, titleLabel])
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 8

        addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(16)
        }

        setAccessibilityRole(.button)
        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, !isHidden, alphaValue > 0 else { return nil }
        let pointInSelf = convert(point, from: superview)
        return bounds.contains(pointInSelf) ? self : nil
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
        isPressed = true
        super.mouseDown(with: event)
        isPressed = false
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }

            let mainColor = NSColor.mainColor
            var color = mainColor
            if self.isPressed {
                color = mainColor.blended(withFraction: 0.16, of: .black) ?? mainColor
            } else if self.isHovered {
                color = mainColor.blended(withFraction: 0.12, of: .white) ?? mainColor
            }
            self.layer?.backgroundColor = color.cgColor
        }
    }
}

// MARK: - WelcomeQuickButton

private final class WelcomeQuickButton: Button {

    private let iconView = ImageView()
    private let titleLabel = Label(labelWithString: "")
    private let chevronView = ImageView()

    private var isHovered = false {
        didSet { updateColors() }
    }
    private var trackingArea: NSTrackingArea?

    init(title: String, symbolName: String) {
        super.init(frame: .zero)

        isBordered = false
        self.title = ""
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1

        iconView.image = welcomeSymbol(symbolName, pointSize: 15, weight: .medium)
        iconView.contentTintColor = .mainColor
        iconView.setScaling(.aspectFit)

        titleLabel.stringValue = title
        titleLabel.font = .ddp_normal(weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.isSelectable = false
        titleLabel.lineBreakMode = .byTruncatingTail

        chevronView.image = welcomeSymbol("chevron.right", pointSize: 10, weight: .semibold)
        chevronView.contentTintColor = .tertiaryLabelColor
        chevronView.setScaling(.aspectFit)

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(chevronView)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(9)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(chevronView.snp.leading).offset(-8)
        }

        chevronView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(12)
        }

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, !isHidden, alphaValue > 0 else { return nil }
        let pointInSelf = convert(point, from: superview)
        return bounds.contains(pointInSelf) ? self : nil
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
        guard isEnabled else { return }
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func refreshAppearance() {
        isHovered = isEnabled && isHovered
        updateColors()
        needsDisplay = true
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }

            let base = NSColor.controlBackgroundColor
            let background = self.isHovered
                ? (base.blended(withFraction: 0.10, of: NSColor.mainColor) ?? base)
                : base
            self.layer?.backgroundColor = background.cgColor
            self.layer?.borderColor = self.isHovered
                ? NSColor.mainColor.withAlphaComponent(0.40).cgColor
                : NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        }
    }
}

// MARK: - WelcomeFeatureCard

private final class WelcomeFeatureCard: WelcomeCard {

    init(title: String, detail: String, symbolName: String, badge: String?) {
        super.init(style: .standard)
        setup(title: title, detail: detail, symbolName: symbolName, badge: badge)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func setup(title: String, detail: String, symbolName: String, badge: String?) {
        let icon = WelcomeIconBadge(symbolName: symbolName, size: 30, symbolSize: 15)

        let titleLabel = welcomeLabel(
            title,
            font: .ddp_small(weight: .semibold),
            color: .labelColor
        )
        let detailLabel = welcomeLabel(
            detail,
            font: .systemFont(ofSize: 11),
            color: .secondaryLabelColor
        )

        addSubview(icon)
        addSubview(titleLabel)
        addSubview(detailLabel)

        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.top.equalToSuperview().offset(12)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(9)
            make.centerY.equalTo(icon)
        }

        if let badge = badge {
            let badgeView = WelcomeTextBadge(text: badge)
            addSubview(badgeView)
            badgeView.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-12)
                make.centerY.equalTo(icon)
            }
            titleLabel.snp.makeConstraints { make in
                make.trailing.lessThanOrEqualTo(badgeView.snp.leading).offset(-8)
            }
        } else {
            titleLabel.snp.makeConstraints { make in
                make.trailing.lessThanOrEqualToSuperview().offset(-12)
            }
        }

        detailLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().offset(-14)
            make.top.equalTo(icon.snp.bottom).offset(7)
        }
    }
}

// MARK: - WelcomeTextBadge

private final class WelcomeTextBadge: BaseView {

    init(text: String) {
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.12).cgColor

        let label = welcomeLabel(
            text,
            font: .systemFont(ofSize: 9, weight: .medium),
            color: .secondaryLabelColor
        )
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(7)
            make.trailing.equalToSuperview().offset(-7)
            make.top.bottom.equalToSuperview().inset(3)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - WelcomeRecentRow

private final class WelcomeRecentRow: Button {

    private let progressBar = WelcomeProgressBar()
    private var isHovered = false {
        didSet { updateColors() }
    }
    private var trackingArea: NSTrackingArea?

    init(item: WelcomeRecentItem) {
        super.init(frame: .zero)

        isBordered = false
        title = ""
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous

        let iconView = ImageView()
        iconView.image = welcomeSymbol("play.rectangle.fill", pointSize: 16, weight: .medium)
        iconView.contentTintColor = .mainColor
        iconView.setScaling(.aspectFit)

        let fileName = (item.path as NSString).lastPathComponent
        let folderPath = (item.path as NSString).deletingLastPathComponent
        let folderName = (folderPath as NSString).lastPathComponent

        let titleLabel = welcomeLabel(
            fileName,
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: .labelColor
        )
        titleLabel.lineBreakMode = .byTruncatingMiddle

        var subtitleParts: [String] = []
        if !folderName.isEmpty {
            subtitleParts.append(folderName)
        }
        subtitleParts.append(welcomeRelativeDate(Date(timeIntervalSince1970: item.lastOpened)))
        if let progress = item.progress, progress > 0.01 {
            subtitleParts.append(String(format: NSLocalizedString("已观看 %d%%", comment: ""), Int(round(progress * 100))))
        }

        let subtitleLabel = welcomeLabel(
            subtitleParts.joined(separator: " · "),
            font: .systemFont(ofSize: 10.5),
            color: .secondaryLabelColor
        )
        subtitleLabel.lineBreakMode = .byTruncatingTail

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(progressBar)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.top.equalToSuperview().offset(7)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(1)
        }

        progressBar.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(4)
            make.height.equalTo(3)
        }

        if let progress = item.progress, progress > 0.01 {
            progressBar.progress = progress
        } else {
            progressBar.isHidden = true
        }

        toolTip = item.path
        setAccessibilityLabel("\(fileName)，\(subtitleLabel.stringValue)")
        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, !isHidden, alphaValue > 0 else { return nil }
        let pointInSelf = convert(point, from: superview)
        return bounds.contains(pointInSelf) ? self : nil
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

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }

            let color = self.isHovered
                ? NSColor.mainColor.withAlphaComponent(0.10)
                : NSColor.clear
            self.layer?.backgroundColor = color.cgColor
        }
    }
}

// MARK: - WelcomeProgressBar

private final class WelcomeProgressBar: NSView {

    var progress: Double = 0 {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool {
        return false
    }

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

// MARK: - Helpers

private func welcomeLabel(_ text: String,
                          font: NSFont,
                          color: NSColor,
                          alignment: NSTextAlignment = .left) -> Label {
    let label = Label(labelWithString: text)
    label.font = font
    label.textColor = color
    label.alignment = alignment
    label.isEditable = false
    label.isSelectable = false
    label.lineBreakMode = .byTruncatingTail
    label.maximumNumberOfLines = 1
    return label
}

private func welcomeSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage? {
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
}

private func welcomeRelativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
