//
//  WelcomeOverviewViewController.swift
//  AniXPlayer
//
//  macOS：欢迎页首页概览。
//

import Cocoa
import SnapKit

/// 首页专用分区：标题保持不变，内容可按状态整体替换。
/// 不把多个独立显隐的 arrangedSubview 混在同一 StackView 中，避免 AppKit 重排和残留间距。
private final class WelcomeOverviewSectionView: NSView {

    private let headerView: NSView
    private var bodyConstraints: [Constraint] = []
    private(set) var bodyView: NSView

    init(headerView: NSView, bodyView: NSView) {
        self.headerView = headerView
        self.bodyView = bodyView
        super.init(frame: .zero)

        addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        addSubview(bodyView)
        installBodyConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setBody(_ newBody: NSView) {
        guard newBody !== bodyView else { return }
        bodyConstraints.forEach { $0.deactivate() }
        bodyConstraints = []
        bodyView.removeFromSuperview()
        bodyView = newBody
        addSubview(newBody)
        installBodyConstraints()
    }

    private func installBodyConstraints() {
        bodyView.snp.makeConstraints { make in
            bodyConstraints = [
                make.top.equalTo(headerView.snp.bottom).offset(10).constraint,
                make.leading.equalToSuperview().constraint,
                make.trailing.equalToSuperview().constraint,
                make.bottom.equalToSuperview().constraint,
            ]
        }
    }
}

final class WelcomeOverviewViewController: WelcomeShellScrollPageViewController, WelcomeShellLoginAware {

    weak var router: WelcomeShellRouting?

    private let recentStore = WelcomeRecentStore.shared
    private let homeService = HomePageService()

    private var lastHomepage: Homepage?
    private var banners: [BannerPageItem] = []
    private var queueItems: [WelcomeQueueCardItem] = []
    private var todayItems: [BangumiIntro] = []

    private var isHomeLoading = false
    private var homeError: String?
    private var isQueueLoading = false
    private var queueError: String?
    private var isLoggedIn = false

    private var homeTask: Task<Void, Never>?
    private var queueTask: Task<Void, Never>?

    // MARK: Views

    private lazy var headerView: WelcomeShellPageHeaderView = {
        let view = WelcomeShellPageHeaderView(
            title: NSLocalizedString("首页", comment: ""),
            subtitle: NSLocalizedString("本地播放 · 弹幕 · 番剧追踪", comment: "")
        )
        let refreshButton = WelcomeShellClosureButton(
            image: welcomeShellSymbol("arrow.clockwise", pointSize: 12, weight: .semibold)
        )
        refreshButton.isBordered = false
        refreshButton.contentTintColor = .mainColor
        refreshButton.toolTip = NSLocalizedString("刷新首页", comment: "")
        refreshButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.overviewRefresh)
        refreshButton.onClick = { [weak self] in
            self?.refreshAll()
        }
        view.trailingStack.addArrangedSubview(refreshButton)
        return view
    }()

    private let actionsRow = NSStackView()
    private var actionTiles: [WelcomeShellActionTileView] = []

    private lazy var continueHeader = WelcomeShellCardHeaderView(
        title: NSLocalizedString("继续播放", comment: ""),
        hint: NSLocalizedString("点击查看全部", comment: ""),
        symbolName: "clock.arrow.circlepath",
        identifier: AccessibilityID.WelcomeShell.overviewContinue,
        onTap: { [weak self] in
            self?.router?.showPage(.recent)
        }
    )
    private let continueStack = NSStackView()

    private lazy var announcementHeader = WelcomeShellCardHeaderView(
        title: NSLocalizedString("最新公告", comment: ""),
        hint: NSLocalizedString("点击查看全部", comment: ""),
        symbolName: "megaphone",
        identifier: AccessibilityID.WelcomeShell.overviewAnnouncement,
        onTap: { [weak self] in
            self?.router?.showPage(.announcement)
        }
    )
    private let announcementRow = WelcomeShellTapView()
    private let announcementTitle = welcomeShellLabel("", font: .systemFont(ofSize: 14, weight: .semibold), color: .labelColor, lines: 2, lineBreakMode: .byWordWrapping)
    private let announcementDescription = welcomeShellLabel("", font: .systemFont(ofSize: 12), color: .secondaryLabelColor, lines: 3, lineBreakMode: .byWordWrapping)
    private let announcementLinkButton = WelcomeShellClosureButton()

    private lazy var queueHeader: WelcomeShellCardHeaderView = {
        let header = WelcomeShellCardHeaderView(
            title: NSLocalizedString("未看番剧", comment: ""),
            hint: NSLocalizedString("点击查看全部", comment: ""),
            symbolName: "tv",
            identifier: AccessibilityID.WelcomeShell.overviewQueue,
            onTap: { [weak self] in
                self?.router?.showPage(.queue)
            }
        )
        let refreshButton = WelcomeShellClosureButton(
            image: welcomeShellSymbol("arrow.clockwise", pointSize: 11, weight: .semibold)
        )
        refreshButton.isBordered = false
        refreshButton.contentTintColor = .mainColor
        refreshButton.toolTip = NSLocalizedString("刷新未看番剧列表", comment: "")
        refreshButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.overviewQueueRefresh)
        refreshButton.onClick = { [weak self] in
            self?.loadQueue()
        }
        header.trailingStack.addArrangedSubview(refreshButton)
        return header
    }()
    private let queueStack = NSStackView()
    private let queueState = WelcomeShellStateView()

    private lazy var scheduleHeader: WelcomeShellCardHeaderView = {
        let header = WelcomeShellCardHeaderView(
            title: NSLocalizedString("今日新番", comment: ""),
            hint: NSLocalizedString("点击查看完整时间表", comment: ""),
            symbolName: "calendar",
            identifier: AccessibilityID.WelcomeShell.overviewSchedule,
            onTap: { [weak self] in
                self?.router?.showPage(.schedule)
            }
        )
        header.trailingStack.addArrangedSubview(self.scheduleSearchField)
        return header
    }()
    private let scheduleGrid = WelcomeShellPosterGridView()
    private let scheduleState = WelcomeShellStateView()
    private let scheduleSearchField = NSSearchField()

    private lazy var continueSection = WelcomeOverviewSectionView(headerView: continueHeader, bodyView: continueStack)
    private lazy var announcementSection = WelcomeOverviewSectionView(headerView: announcementHeader, bodyView: announcementRow)
    private lazy var queueSection = WelcomeOverviewSectionView(headerView: queueHeader, bodyView: queueStack)
    private lazy var scheduleSection = WelcomeOverviewSectionView(headerView: scheduleHeader, bodyView: scheduleGrid)

    private var isContinueSectionVisible = false
    private var isAnnouncementSectionVisible = false
    private var isQueueSectionVisible = false
    private var isScheduleSectionVisible = false

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.overviewRoot)
        title = NSLocalizedString("首页", comment: "")

        buildLayout()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recentPlaybackDidChange),
            name: .welcomeRecentPlaybackDidChange,
            object: nil
        )

        refreshRecent()
        refreshAll()
    }

    deinit {
        homeTask?.cancel()
        queueTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshRecent()
    }

    // MARK: Layout

    private func buildLayout() {
        contentStack.spacing = 26
        // 可见分区由 syncSectionOrder 按固定顺序整体插入/移除；
        // 禁止 StackView 再自动分离、重挂视图，避免异步刷新后顺序和间距被打乱。
        contentStack.detachesHiddenViews = false
        addFullWidth(headerView, spacingAfter: 4)

        buildActionsRow()
        addFullWidth(actionsRow, spacingAfter: 24)

        buildContinueSection()
        buildAnnouncementSection()
        buildQueueSection()
        buildScheduleSection()
        syncSectionOrder()
    }

    private func buildActionsRow() {
        actionsRow.orientation = .horizontal
        actionsRow.alignment = .centerY
        actionsRow.spacing = 22

        let openFile = WelcomeShellActionTileView(
            title: NSLocalizedString("打开文件", comment: ""),
            symbolName: "folder",
            identifier: AccessibilityID.WelcomeShell.overviewOpenFile,
            emphasized: true
        )
        openFile.onClick = { [weak self] in
            self?.router?.openLocalFiles()
        }

        let online = WelcomeShellActionTileView(
            title: NSLocalizedString("在线观看", comment: ""),
            symbolName: "play.rectangle.on.rectangle",
            identifier: AccessibilityID.WelcomeShell.overviewOnline
        )
        online.onClick = { [weak self] in
            self?.router?.showPage(.online)
        }

        let playlist = WelcomeShellActionTileView(
            title: NSLocalizedString("播放列表", comment: ""),
            symbolName: "list.bullet.rectangle",
            identifier: AccessibilityID.WelcomeShell.overviewPlaylist
        )
        playlist.onClick = { [weak self] in
            self?.router?.openPlayerPlaylist()
        }

        let remote = WelcomeShellActionTileView(
            title: NSLocalizedString("远程访问", comment: ""),
            symbolName: "network",
            identifier: AccessibilityID.WelcomeShell.overviewRemoteAccess
        )
        remote.onClick = { [weak self] in
            self?.router?.openRemoteFiles()
        }

        actionTiles = [openFile, online, playlist, remote]
        for tile in actionTiles {
            actionsRow.addArrangedSubview(tile)
            tile.snp.makeConstraints { make in
                make.height.equalTo(30)
            }
        }
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        actionsRow.addArrangedSubview(spacer)
    }

    private func buildContinueSection() {
        continueStack.orientation = .horizontal
        continueStack.alignment = .centerY
        continueStack.distribution = .fill
        continueStack.spacing = 20
    }

    private func buildAnnouncementSection() {
        announcementRow.normalBackground = .clear
        announcementRow.layer?.cornerRadius = 6
        announcementRow.onClick = { [weak self] in
            self?.router?.showPage(.announcement)
        }
        announcementRow.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.overviewAnnouncement)

        announcementLinkButton.image = welcomeShellSymbol("arrow.up.right.square", pointSize: 13, weight: .medium)
        announcementLinkButton.isBordered = false
        announcementLinkButton.contentTintColor = .mainColor
        announcementLinkButton.toolTip = NSLocalizedString("在浏览器打开公告链接", comment: "")
        announcementLinkButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.overviewAnnouncementLink)
        announcementLinkButton.onClick = { [weak self] in
            self?.openAnnouncementLink()
        }

        announcementRow.addSubview(announcementTitle)
        announcementRow.addSubview(announcementDescription)
        announcementRow.addSubview(announcementLinkButton)

        announcementTitle.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(2)
            make.trailing.lessThanOrEqualTo(announcementLinkButton.snp.leading).offset(-8)
        }
        announcementDescription.snp.makeConstraints { make in
            make.top.equalTo(announcementTitle.snp.bottom).offset(3)
            make.leading.trailing.equalTo(announcementTitle)
            make.bottom.equalToSuperview().offset(-2)
        }
        announcementLinkButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-2)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
    }

    private func buildQueueSection() {
        queueStack.orientation = .horizontal
        queueStack.alignment = .centerY
        queueStack.distribution = .fill
        queueStack.spacing = 18
        queueState.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.overviewQueueStatus)
    }

    private func buildScheduleSection() {
        scheduleSearchField.placeholderString = NSLocalizedString("搜索今日新番", comment: "")
        scheduleSearchField.controlSize = .small
        scheduleSearchField.font = .systemFont(ofSize: 12)
        scheduleSearchField.delegate = self
        scheduleSearchField.target = self
        scheduleSearchField.action = #selector(searchFieldEntered)
        scheduleSearchField.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.overviewSearchField)
        scheduleSearchField.snp.makeConstraints { make in
            make.width.equalTo(180)
        }

        scheduleGrid.minimumTileWidth = 144
        scheduleGrid.onSelect = { [weak self] item in
            self?.router?.openDetail(animeId: item.animeId)
        }
        scheduleGrid.onHeightChange = { [weak self] in
            self?.layoutContent()
        }
        scheduleState.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.overviewScheduleStatus)
    }

    // MARK: Section visibility

    private func setContinueVisible(_ visible: Bool) {
        guard isContinueSectionVisible != visible else { return }
        isContinueSectionVisible = visible
        syncSectionOrder()
    }

    private func setAnnouncementVisible(_ visible: Bool) {
        guard isAnnouncementSectionVisible != visible else { return }
        isAnnouncementSectionVisible = visible
        syncSectionOrder()
    }

    private func setQueueVisible(_ visible: Bool) {
        guard isQueueSectionVisible != visible else { return }
        isQueueSectionVisible = visible
        syncSectionOrder()
    }

    private func setScheduleVisible(_ visible: Bool) {
        guard isScheduleSectionVisible != visible else { return }
        isScheduleSectionVisible = visible
        syncSectionOrder()
    }

    private func syncSectionOrder() {
        let sections = [
            (isContinueSectionVisible, continueSection),
            (isAnnouncementSectionVisible, announcementSection),
            (isQueueSectionVisible, queueSection),
            (isScheduleSectionVisible, scheduleSection),
        ]

        // 每次按设计顺序重建可见分区；bottomSpacer 和固定头部保持不动。
        for (_, section) in sections {
            guard contentStack.arrangedSubviews.contains(where: { $0 === section }) else { continue }
            contentStack.removeArrangedSubview(section)
            section.removeFromSuperview()
        }
        var insertionIndex = 2
        for (visible, section) in sections where visible {
            contentStack.insertArrangedSubview(section, at: insertionIndex)
            section.snp.remakeConstraints { make in
                make.width.equalTo(contentStack)
            }
            insertionIndex += 1
        }
        if isViewLoaded {
            view.needsLayout = true
        }
    }

    // MARK: Data

    private func refreshAll() {
        homeTask?.cancel()
        queueTask?.cancel()
        loadHomepage()
        loadQueue()
    }

    private func loadHomepage() {
        homeTask?.cancel()
        isHomeLoading = true
        homeError = nil

        homeTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard self.canLoadOnlineData() else {
                self.applyLoggedOutState()
                return
            }

            self.updateAnnouncementModule()
            self.updateScheduleModule()
            self.layoutContent()

            do {
                let homepage = try await self.homeService.loadHomepage()
                guard !Task.isCancelled else { return }
                self.lastHomepage = homepage
                self.banners = homepage.banners
                self.todayItems = WelcomeShellDataMapper.todayBangumi(
                    WelcomeShellDataMapper.currentSeasonBangumi(from: homepage)
                )
                self.isHomeLoading = false
                self.homeError = nil
                self.updateAnnouncementModule()
                self.updateScheduleModule()
                self.layoutContent()
            } catch {
                guard !Task.isCancelled else { return }
                self.isHomeLoading = false
                self.homeError = error.localizedDescription
                self.updateAnnouncementModule()
                self.updateScheduleModule()
                self.layoutContent()
            }
        }
    }

    private func loadQueue() {
        queueTask?.cancel()
        isQueueLoading = true
        queueError = nil
        updateQueueModule()

        queueTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard self.canLoadOnlineData() else {
                self.applyLoggedOutState()
                return
            }

            self.updateQueueModule()
            self.layoutContent()

            do {
                let response = try await BangumiQueueNetworkHandle.fetchIntro()
                guard !Task.isCancelled else { return }
                self.queueItems = WelcomeShellDataMapper.queueCards(from: response.bangumiList)
                self.isQueueLoading = false
                self.queueError = nil
            } catch {
                guard !Task.isCancelled else { return }
                // 概览优先用 intro；失败时退回首页返回的未看列表。
                do {
                    let homepage: Homepage
                    if let cached = self.lastHomepage {
                        homepage = cached
                    } else {
                        homepage = try await self.homeService.loadHomepage()
                        self.lastHomepage = homepage
                    }
                    guard !Task.isCancelled else { return }
                    self.queueItems = WelcomeShellDataMapper.queueCards(from: homepage.bangumiQueueIntroList)
                    self.isQueueLoading = false
                    self.queueError = nil
                } catch {
                    guard !Task.isCancelled else { return }
                    self.queueItems = []
                    self.isQueueLoading = false
                    self.queueError = error.localizedDescription
                }
            }
            self.updateQueueModule()
            self.layoutContent()
        }
    }

    private func canLoadOnlineData() -> Bool {
        // 用内存 token 做快速门禁，避免 SessionStore actor 在钥匙串恢复期间阻塞 UI。
        // 真正的 401/刷新由 AuthenticatedAPIClient 处理。
        let hasToken = AccessTokenHolder.shared.current() != nil
        isLoggedIn = hasToken
        return hasToken
    }

    // MARK: Module updates

    private func refreshRecent() {
        guard isViewLoaded else { return }
        let items = WelcomeShellDataMapper.recentItems(recentStore.items, limit: 3)
        continueStack.arrangedSubviews.forEach {
            continueStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        setContinueVisible(!items.isEmpty)
        for (index, item) in items.enumerated() {
            let card = WelcomeShellContinueCardView()
            card.configure(with: item)
            card.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.overviewContinueItemPrefix)\(index)")
            card.onClick = { [weak self] in
                self?.playRecent(item)
            }
            continueStack.addArrangedSubview(card)
        }
        // 固定三列，避免只有 1–2 条时卡片被拉得过宽。
        for _ in items.count..<3 {
            let spacer = NSView()
            spacer.snp.makeConstraints { make in
                make.height.equalTo(1)
            }
            continueStack.addArrangedSubview(spacer)
        }
        if let firstColumn = continueStack.arrangedSubviews.first {
            for column in continueStack.arrangedSubviews.dropFirst() {
                column.snp.makeConstraints { make in
                    make.width.equalTo(firstColumn)
                }
            }
        }
        layoutContent()
    }

    private func updateAnnouncementModule() {
        guard isLoggedIn else {
            setAnnouncementVisible(true)
            announcementTitle.text = NSLocalizedString("登录后查看公告", comment: "")
            announcementDescription.text = NSLocalizedString("登录弹弹play账号后查看最新公告", comment: "")
            announcementLinkButton.isHidden = true
            announcementRow.onClick = { [weak self] in
                self?.startLogin()
            }
            return
        }
        announcementRow.onClick = { [weak self] in
            self?.router?.showPage(.announcement)
        }
        if isHomeLoading {
            setAnnouncementVisible(true)
            announcementTitle.text = NSLocalizedString("正在加载公告…", comment: "")
            announcementDescription.text = ""
            announcementLinkButton.isHidden = true
            return
        }
        if let error = homeError {
            setAnnouncementVisible(true)
            announcementTitle.text = NSLocalizedString("公告加载失败", comment: "")
            announcementDescription.text = error
            announcementLinkButton.isHidden = true
            return
        }
        guard let banner = banners.first else {
            setAnnouncementVisible(false)
            return
        }
        setAnnouncementVisible(true)
        announcementTitle.text = banner.title
        announcementDescription.text = banner.description
        announcementLinkButton.isHidden = banner.url.isEmpty
        announcementRow.setAccessibilityLabel([banner.title, banner.description].filter { !$0.isEmpty }.joined(separator: "，"))
    }

    private func updateQueueModule() {
        if !isLoggedIn {
            showQueueState(
                title: NSLocalizedString("登录后查看未看番剧", comment: ""),
                actionTitle: NSLocalizedString("登录", comment: "")
            )
            setQueueVisible(true)
            return
        }
        if isQueueLoading {
            queueItems = []
            showQueueState(title: NSLocalizedString("正在加载未看番剧…", comment: ""), actionTitle: nil)
            setQueueVisible(true)
            return
        }
        if let error = queueError {
            queueItems = []
            showQueueState(title: NSLocalizedString("未看番剧加载失败", comment: ""), detail: error, actionTitle: NSLocalizedString("重试", comment: "")) { [weak self] in
                self?.loadQueue()
            }
            setQueueVisible(true)
            return
        }
        setQueueVisible(!queueItems.isEmpty)
        queueSection.setBody(queueStack)
        queueStack.arrangedSubviews.forEach {
            queueStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let visibleItems = Array(queueItems.prefix(5))
        for (index, item) in visibleItems.enumerated() {
            let card = WelcomeShellQueueCardView()
            card.configure(with: item)
            card.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.overviewQueueItemPrefix)\(index)")
            card.onClick = { [weak self] in
                self?.router?.openDetail(animeId: item.animeId)
            }
            queueStack.addArrangedSubview(card)
        }
        // 固定五列，最后一行不足时保持相同卡片宽度。
        for _ in visibleItems.count..<5 {
            let spacer = NSView()
            spacer.snp.makeConstraints { make in
                make.height.equalTo(1)
            }
            queueStack.addArrangedSubview(spacer)
        }
        if let firstColumn = queueStack.arrangedSubviews.first {
            for column in queueStack.arrangedSubviews.dropFirst() {
                column.snp.makeConstraints { make in
                    make.width.equalTo(firstColumn)
                }
            }
        }
    }

    private func showQueueState(title: String, detail: String? = nil, actionTitle: String?, onAction: (() -> Void)? = nil) {
        queueSection.setBody(queueState)
        let action = onAction ?? { [weak self] in
            self?.startLogin()
        }
        queueState.configure(
            title: title,
            detail: detail,
            actionTitle: actionTitle,
            onAction: actionTitle == nil ? nil : action
        )
    }

    private func updateScheduleModule() {
        if !isLoggedIn {
            scheduleGrid.reload(items: [])
            scheduleSection.setBody(scheduleState)
            scheduleState.configure(
                title: NSLocalizedString("登录后查看今日新番", comment: ""),
                actionTitle: NSLocalizedString("登录", comment: ""),
                onAction: { [weak self] in
                    self?.startLogin()
                }
            )
            setScheduleVisible(true)
            return
        }
        if isHomeLoading {
            scheduleSection.setBody(scheduleState)
            scheduleState.configure(title: NSLocalizedString("正在加载今日新番…", comment: ""))
            setScheduleVisible(true)
            return
        }
        if let error = homeError {
            scheduleSection.setBody(scheduleState)
            scheduleState.configure(
                title: NSLocalizedString("今日新番加载失败", comment: ""),
                detail: error,
                actionTitle: NSLocalizedString("重试", comment: ""),
                onAction: { [weak self] in
                    self?.loadHomepage()
                }
            )
            setScheduleVisible(true)
            return
        }

        let keyword = scheduleSearchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let items: [BangumiIntro]
        if keyword.isEmpty {
            items = todayItems
        } else {
            items = todayItems.filter { $0.animeTitle.localizedCaseInsensitiveContains(keyword) }
        }

        scheduleGrid.reload(items: items)
        if items.isEmpty {
            scheduleSection.setBody(scheduleState)
            scheduleState.configure(
                title: keyword.isEmpty
                    ? NSLocalizedString("今天没有新番", comment: "")
                    : NSLocalizedString("没有匹配的新番", comment: ""),
                actionTitle: keyword.isEmpty ? nil : NSLocalizedString("清除搜索", comment: ""),
                onAction: { [weak self] in
                    self?.scheduleSearchField.stringValue = ""
                    self?.updateScheduleModule()
                }
            )
        } else {
            scheduleSection.setBody(scheduleGrid)
        }
        setScheduleVisible(true)
        layoutContent()
    }

    private func applyLoggedOutState() {
        isLoggedIn = false
        isHomeLoading = false
        isQueueLoading = false
        homeError = nil
        queueError = nil
        banners = []
        queueItems = []
        todayItems = []
        updateAnnouncementModule()
        setQueueVisible(true)
        updateQueueModule()
        updateScheduleModule()
        layoutContent()
    }

    // MARK: Actions

    @objc private func searchFieldEntered() {
        let keyword = scheduleSearchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        router?.showSchedule(searchText: keyword.isEmpty ? nil : keyword)
    }

    @objc private func recentPlaybackDidChange() {
        refreshRecent()
    }

    private func playRecent(_ item: WelcomeRecentItem) {
        guard let url = recentStore.resolveURL(for: item) else {
            recentStore.remove(path: item.path)
            view.show(text: NSLocalizedString("文件已不存在或无法访问", comment: ""))
            return
        }
        let file = LocalFile(with: url)
        router?.play(files: [file], startWith: file, progress: item.progress)
    }

    private func openAnnouncementLink() {
        guard let banner = banners.first,
              let url = URL(string: banner.url), !banner.url.isEmpty else { return }
        NSWorkspace.shared.open(url)
    }

    private func startLogin() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            _ = await LoginGate.shared.ensureLoggedIn(presenting: self.view.window)
        }
    }

    // MARK: WelcomeShellLoginAware

    func welcomeShellLoginStateDidChange() {
        refreshAll()
    }
}

// MARK: - Search field

extension WelcomeOverviewViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field === scheduleSearchField else { return }
        updateScheduleModule()
    }
}
