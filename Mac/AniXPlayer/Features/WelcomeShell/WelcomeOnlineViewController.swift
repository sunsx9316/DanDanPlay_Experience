//
//  WelcomeOnlineViewController.swift
//  AniXPlayer
//
//  macOS：在线观看。
//
//  搜索来自用户配置的 Animeko / Kazumi 规则源；解析出视频直链后交给
//  现有播放器窗口（OnlineEpisodeFile）。播放走会员门禁，搜索免费。
//

import Cocoa
import SnapKit

// MARK: - Stack scroll view

final class WelcomeShellStackScrollView: NSScrollView {

    let documentContentView = WelcomeShellFlippedView()
    let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        borderType = .noBorder
        drawsBackground = false
        verticalScrollElasticity = .automatic
        horizontalScrollElasticity = .none

        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        documentContentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(2)
            make.trailing.equalToSuperview().offset(-2)
            make.bottom.lessThanOrEqualToSuperview().offset(-8)
        }
        documentView = documentContentView
    }

    func layoutContent() {
        // documentView 初始宽度可能是 0；以 scrollView 的可视宽度为准
        // 撑开文档视图，否则 stack 的 leading/trailing 约束会把行压成 0 宽。
        let width = max(contentView.bounds.width, 1)
        var needsLayout = false
        if abs(documentContentView.frame.width - width) > 0.5 {
            documentContentView.frame.size.width = width
            needsLayout = true
        }

        if needsLayout {
            documentContentView.layoutSubtreeIfNeeded()
        }
        let height = max(stack.fittingSize.height + 12, contentView.bounds.height)
        if abs(documentContentView.frame.height - height) > 0.5 {
            documentContentView.frame.size.height = height
            documentContentView.layoutSubtreeIfNeeded()
        }
    }
}

// MARK: - Result row

final class WelcomeShellOnlineResultRowView: WelcomeShellTapView {

    private let sourceLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 9.5, weight: .semibold),
        color: .mainColor
    )
    private let titleLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 13, weight: .semibold),
        color: .labelColor,
        lines: 2,
        lineBreakMode: .byWordWrapping
    )
    private let detailLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 10.5),
        color: .tertiaryLabelColor
    )

    var isSelectedResult = false {
        didSet { updateSelectedStyle() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalBackground = .clear
        layer?.cornerRadius = 7

        addSubview(sourceLabel)
        addSubview(titleLabel)
        addSubview(detailLabel)
        sourceLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(sourceLabel.snp.bottom).offset(3)
            make.leading.trailing.equalTo(sourceLabel)
        }
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(3)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-8)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with subject: OnlineSubject) {
        var parts = ["\(subject.engine.displayName) · \(subject.sourceName)"]
        if OnlineSourcePreferences.isSourcePinned(subject.sourceID) {
            parts.append(NSLocalizedString("★ 置顶", comment: ""))
        }
        sourceLabel.text = parts.joined(separator: " · ")
        titleLabel.text = subject.title
        detailLabel.text = subject.url.host ?? subject.url.absoluteString
        setAccessibilityLabel("\(subject.sourceName)，\(subject.title)")
        updateSelectedStyle()
    }

    private func updateSelectedStyle() {
        normalBackground = isSelectedResult
            ? NSColor.mainColor.withAlphaComponent(0.16)
            : .clear
    }
}

// MARK: - Episode row

final class WelcomeShellOnlineEpisodeRowView: NSView {

    private let titleLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 12.5, weight: .medium),
        color: .labelColor
    )
    private let subtitleLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 10.5),
        color: .tertiaryLabelColor
    )
    private let playButton = WelcomeShellClosureButton(title: NSLocalizedString("播放", comment: ""))
    private let openButton = WelcomeShellClosureButton()
    private let copyButton = WelcomeShellClosureButton()
    private let spinner = NSProgressIndicator()

    var onPlay: (() -> Void)?
    var onOpen: (() -> Void)?
    var onCopy: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        updateColors()

        playButton.bezelStyle = .rounded
        playButton.controlSize = .small
        playButton.setContentHuggingPriority(.required, for: .horizontal)
        playButton.onClick = { [weak self] in self?.onPlay?() }

        openButton.bezelStyle = .inline
        openButton.isBordered = false
        openButton.image = welcomeShellSymbol("safari", pointSize: 13, weight: .medium)
        openButton.imagePosition = .imageOnly
        openButton.toolTip = NSLocalizedString("在浏览器打开剧集页", comment: "")
        openButton.onClick = { [weak self] in self?.onOpen?() }

        copyButton.bezelStyle = .inline
        copyButton.isBordered = false
        copyButton.image = welcomeShellSymbol("doc.on.doc", pointSize: 12, weight: .medium)
        copyButton.imagePosition = .imageOnly
        copyButton.toolTip = NSLocalizedString("复制剧集链接", comment: "")
        copyButton.onClick = { [weak self] in self?.onCopy?() }

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.isHidden = true
        spinner.isHidden = true

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(spinner)
        addSubview(playButton)
        addSubview(openButton)
        addSubview(copyButton)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(9)
            make.trailing.lessThanOrEqualTo(playButton.snp.leading).offset(-8)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualTo(playButton.snp.leading).offset(-8)
            make.bottom.lessThanOrEqualToSuperview().offset(-9)
        }
        copyButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        openButton.snp.makeConstraints { make in
            make.trailing.equalTo(copyButton.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        playButton.snp.makeConstraints { make in
            make.trailing.equalTo(openButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        spinner.snp.makeConstraints { make in
            make.trailing.equalTo(playButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(50)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }
            self.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
            self.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.30).cgColor
        }
    }

    func configure(episode: OnlineEpisode, subject: OnlineSubject, index: Int) {
        titleLabel.text = episode.title
        subtitleLabel.text = episode.url.host ?? subject.sourceName
        setAccessibilityLabel("\(subject.title)，\(episode.title)")
        playButton.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.onlineEpisodePlay).\(index)")
        openButton.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.onlineEpisodeOpen).\(index)")
        copyButton.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.onlineEpisodeCopy).\(index)")
    }

    func setBusy(_ busy: Bool) {
        playButton.isEnabled = !busy
        playButton.title = busy
            ? NSLocalizedString("解析中…", comment: "")
            : NSLocalizedString("播放", comment: "")
        spinner.isHidden = !busy
        if busy {
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
    }
}

// MARK: - Online page

final class WelcomeOnlineViewController: ViewController, WelcomeShellLoginAware, NSWindowDelegate {

    weak var router: WelcomeShellRouting?

    private let service = OnlinePlaybackService.shared
    private let sourceStore = OnlineSourceStore.shared
    private let entitlementGate = EntitlementGate.shared

    private var allSources: [OnlineMediaSource] = []
    private var subjects: [OnlineSubject] = []
    private var episodes: [OnlineEpisode] = []
    private var selectedIndex = 0
    private var lastKeyword = ""
    private var isLoggedIn = false
    private var isSearching = false
    private var busyEpisodeID: String?

    private var loadSourcesTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var episodesTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var sourceSettingsPanel: NSPanel?
    private var complianceHeightConstraint: Constraint?

    // MARK: Views

    private lazy var headerView: WelcomeShellPageHeaderView = {
        return WelcomeShellPageHeaderView(
            title: NSLocalizedString("在线观看", comment: ""),
            subtitle: NSLocalizedString("聚合 Animeko / Kazumi 规则源", comment: "")
        )
    }()

    private lazy var searchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = NSLocalizedString("输入番剧关键词", comment: "")
        field.target = self
        field.action = #selector(startSearch)
        field.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineSearchField)
        return field
    }()

    private lazy var searchButton: WelcomeShellClosureButton = {
        let button = WelcomeShellClosureButton(title: NSLocalizedString("搜索", comment: ""))
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineSearchButton)
        button.onClick = { [weak self] in
            self?.startSearch()
        }
        return button
    }()

    private lazy var cancelButton: WelcomeShellClosureButton = {
        let button = WelcomeShellClosureButton(title: NSLocalizedString("取消", comment: ""))
        button.bezelStyle = .rounded
        button.isHidden = true
        button.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineCancel)
        button.onClick = { [weak self] in
            self?.cancelSearch()
        }
        return button
    }()

    private lazy var enginePopup: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.addItems(withTitles: [
            NSLocalizedString("全部源", comment: ""),
            OnlineSourceEngine.animeko.displayName,
            OnlineSourceEngine.kazumi.displayName
        ])
        popup.controlSize = .small
        popup.target = self
        popup.action = #selector(engineFilterChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineSourceFilter)
        return popup
    }()

    private lazy var manageButton: WelcomeShellClosureButton = {
        let button = WelcomeShellClosureButton(title: NSLocalizedString("源管理", comment: ""))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineManageSources)
        button.onClick = { [weak self] in
            self?.showSourceSettings()
        }
        return button
    }()

    private lazy var snifferButton: WelcomeShellClosureButton = {
        let button = WelcomeShellClosureButton(title: NSLocalizedString("媒体嗅探", comment: ""))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.toolTip = NSLocalizedString("打开网页媒体嗅探窗口", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineSniffer)
        button.onClick = { [weak self] in
            self?.openMediaSniffer()
        }
        return button
    }()

    private lazy var continuousButton: NSButton = {
        let button = NSButton(
            checkboxWithTitle: NSLocalizedString("连续播放", comment: ""),
            target: self,
            action: #selector(continuousPlaybackChanged)
        )
        button.controlSize = .small
        button.state = OnlineSourcePreferences.continuousPlayback ? .on : .off
        button.toolTip = NSLocalizedString("播放当前集时预取后续剧集，自动继续播放", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineContinuousPlay)
        return button
    }()

    private let complianceBanner = NSView()
    private let complianceLabel = welcomeShellLabel(
        NSLocalizedString("第三方源由你自行配置，App 不内置站点；解析失败时请改用浏览器打开。", comment: ""),
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor
    )
    private let stateView = WelcomeShellStateView()
    private let resultsScroll = WelcomeShellStackScrollView()
    private let episodesScroll = WelcomeShellStackScrollView()
    private let resultsTitle = welcomeShellLabel(
        NSLocalizedString("搜索结果", comment: ""),
        font: .systemFont(ofSize: 12, weight: .semibold),
        color: .labelColor
    )
    private let episodesTitle = welcomeShellLabel(
        NSLocalizedString("剧集列表", comment: ""),
        font: .systemFont(ofSize: 12, weight: .semibold),
        color: .labelColor
    )
    private let summaryLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor
    )

    // MARK: Lifecycle

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 620))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineRoot)
        title = NSLocalizedString("在线观看", comment: "")

        setupLayout()
        searchField.recentSearches = OnlineSourcePreferences.searchHistory
        showInitialState()
        loadSources()
    }

    deinit {
        loadSourcesTask?.cancel()
        searchTask?.cancel()
        episodesTask?.cancel()
        playbackTask?.cancel()
        sourceSettingsPanel?.close()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        resultsScroll.layoutContent()
        episodesScroll.layoutContent()
    }

    // MARK: Layout

    private func setupLayout() {
        searchField.snp.makeConstraints { make in
            make.width.equalTo(260)
        }
        enginePopup.snp.makeConstraints { make in
            make.width.equalTo(96)
        }

        let searchRow = NSStackView(views: [
            searchField,
            searchButton,
            cancelButton,
            NSView(),
            continuousButton,
            enginePopup,
            snifferButton,
            manageButton
        ])
        searchRow.orientation = .horizontal
        searchRow.alignment = .centerY
        searchRow.spacing = 8

        complianceBanner.wantsLayer = true
        complianceBanner.layer?.cornerRadius = 8
        complianceBanner.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.10).cgColor
        complianceBanner.layer?.borderWidth = 1
        complianceBanner.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.28).cgColor

        let infoIcon = ImageView()
        infoIcon.image = welcomeShellSymbol("info.circle", pointSize: 13, weight: .medium)
        infoIcon.contentTintColor = .systemOrange
        infoIcon.setScaling(.aspectFit)

        let closeButton = WelcomeShellClosureButton()
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.image = welcomeShellSymbol("xmark", pointSize: 10, weight: .semibold)
        closeButton.imagePosition = .imageOnly
        closeButton.toolTip = NSLocalizedString("关闭提示", comment: "")
        closeButton.onClick = { [weak self] in
            self?.complianceBanner.isHidden = true
            self?.complianceHeightConstraint?.update(offset: 0)
            OnlineSourcePreferences.dismissedCompliance = true
        }

        complianceBanner.addSubview(infoIcon)
        complianceBanner.addSubview(complianceLabel)
        complianceBanner.addSubview(closeButton)
        infoIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }
        complianceLabel.snp.makeConstraints { make in
            make.leading.equalTo(infoIcon.snp.trailing).offset(7)
            make.trailing.equalTo(closeButton.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
        }
        complianceBanner.snp.makeConstraints { make in
            complianceHeightConstraint = make.height.equalTo(32).constraint
        }
        if OnlineSourcePreferences.dismissedCompliance {
            complianceBanner.isHidden = true
            complianceHeightConstraint?.update(offset: 0)
        }

        let content = NSStackView(views: [resultsColumn(), episodesColumn()])
        content.orientation = .horizontal
        content.alignment = .top
        content.spacing = 14
        content.distribution = .fill

        view.addSubview(headerView)
        view.addSubview(searchRow)
        view.addSubview(complianceBanner)
        view.addSubview(summaryLabel)
        view.addSubview(content)
        view.addSubview(stateView)

        headerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(22)
        }
        searchRow.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(8)
            make.leading.trailing.equalTo(headerView)
        }
        complianceBanner.snp.makeConstraints { make in
            make.top.equalTo(searchRow.snp.bottom).offset(8)
            make.leading.trailing.equalTo(headerView)
        }
        summaryLabel.snp.makeConstraints { make in
            make.top.equalTo(complianceBanner.snp.bottom).offset(8)
            make.leading.trailing.equalTo(headerView)
        }
        content.snp.makeConstraints { make in
            make.top.equalTo(summaryLabel.snp.bottom).offset(6)
            make.leading.trailing.equalTo(headerView)
            make.bottom.equalToSuperview().offset(-16)
        }
        stateView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(content)
            make.leading.greaterThanOrEqualToSuperview().offset(30)
            make.trailing.lessThanOrEqualToSuperview().offset(-30)
        }
    }

    private func resultsColumn() -> NSView {
        let column = NSView()
        column.addSubview(resultsTitle)
        column.addSubview(resultsScroll)
        resultsTitle.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
        }
        resultsScroll.snp.makeConstraints { make in
            make.top.equalTo(resultsTitle.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview()
            make.width.equalTo(320)
        }
        resultsScroll.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineResults)
        return column
    }

    private func episodesColumn() -> NSView {
        let column = NSView()
        column.addSubview(episodesTitle)
        column.addSubview(episodesScroll)
        episodesTitle.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
        }
        episodesScroll.snp.makeConstraints { make in
            make.top.equalTo(episodesTitle.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview()
        }
        episodesScroll.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineEpisodes)
        return column
    }

    // MARK: Sources

    private func loadSources(forceRefresh: Bool = false, then action: (() -> Void)? = nil) {
        guard canSearch else { return }
        loadSourcesTask?.cancel()
        if allSources.isEmpty {
            showState(
                title: NSLocalizedString("正在加载在线源…", comment: ""),
                detail: NSLocalizedString("首次使用需要下载源配置", comment: "")
            )
        }

        loadSourcesTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let sources = try await self.service.loadSources(
                    forceRefresh: forceRefresh,
                    progress: { message in
                        DispatchQueue.main.async { [weak self] in
                            self?.summaryLabel.text = message
                        }
                    }
                )
                guard !Task.isCancelled else { return }
                self.allSources = sources
                self.updateSourceSummary()
                if let action {
                    action()
                } else if self.subjects.isEmpty {
                    self.showIdleState()
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.allSources = []
                self.updateSourceSummary()
                self.showState(
                    title: NSLocalizedString("在线源加载失败", comment: ""),
                    detail: error.localizedDescription,
                    actionTitle: NSLocalizedString("源管理", comment: ""),
                    onAction: { [weak self] in
                        self?.showSourceSettings()
                    }
                )
            }
        }
    }

    private func updateSourceSummary() {
        guard !allSources.isEmpty else {
            summaryLabel.text = NSLocalizedString("没有可用的在线源", comment: "")
            return
        }
        let animekoCount = allSources.filter { $0.engine == .animeko }.count
        let kazumiCount = allSources.filter { $0.engine == .kazumi }.count
        summaryLabel.text = String(
            format: NSLocalizedString("已加载 %d 个源（Animeko %d / Kazumi %d）", comment: ""),
            allSources.count,
            animekoCount,
            kazumiCount
        )
    }

    private var selectedEngine: OnlineSourceEngine? {
        switch enginePopup.indexOfSelectedItem {
        case 1:
            return .animeko
        case 2:
            return .kazumi
        default:
            return nil
        }
    }

    @objc private func engineFilterChanged() {
        if !lastKeyword.isEmpty {
            startSearch()
        }
    }

    @objc private func continuousPlaybackChanged() {
        OnlineSourcePreferences.continuousPlayback = continuousButton.state == .on
    }

    private func openMediaSniffer() {
        let initialURL = subjects.indices.contains(selectedIndex) ? subjects[selectedIndex].url : nil
        MacFeatureLauncher.showMediaSniffer(
            presenting: view.window,
            initialURL: initialURL,
            onPlay: { [weak self] file in
                if let router = self?.router {
                    router.play(files: [file], startWith: file, progress: nil)
                } else {
                    MacFeatureLauncher.playOnlineFile(file)
                }
            }
        )
    }

    // MARK: Search

    private var canSearch: Bool {
        return isLoggedIn || AccessTokenHolder.shared.current() != nil
    }

    @objc private func startSearch() {
        let keyword = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            showState(title: NSLocalizedString("请输入搜索关键词", comment: ""))
            return
        }
        guard canSearch else {
            showLoginState()
            return
        }
        guard !allSources.isEmpty else {
            showState(title: NSLocalizedString("正在加载在线源…", comment: ""))
            loadSources(forceRefresh: false) { [weak self] in
                self?.startSearch()
            }
            return
        }

        lastKeyword = keyword
        OnlineSourcePreferences.addSearchHistory(keyword)
        searchField.recentSearches = OnlineSourcePreferences.searchHistory

        searchTask?.cancel()
        episodesTask?.cancel()
        isSearching = true
        searchButton.isEnabled = false
        cancelButton.isHidden = false
        subjects = []
        episodes = []
        selectedIndex = 0
        rebuildResults()
        rebuildEpisodes()
        setContentVisible(false)
        showState(
            title: NSLocalizedString("正在搜索在线源…", comment: ""),
            detail: String(
                format: NSLocalizedString("已启用 %d 个源", comment: ""),
                service.enabledSources(from: allSources, engine: selectedEngine).count
            )
        )
        summaryLabel.text = NSLocalizedString("正在搜索…", comment: "")

        searchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let outcome = try await self.service.search(
                    keyword: keyword,
                    sources: self.allSources,
                    engine: self.selectedEngine,
                    onSourceFinished: { finished, total in
                        DispatchQueue.main.async { [weak self] in
                            self?.summaryLabel.text = String(
                                format: NSLocalizedString("正在搜索 %d/%d 个源…", comment: ""),
                                finished,
                                total
                            )
                        }
                    }
                )
                guard !Task.isCancelled else { return }

                self.isSearching = false
                self.searchButton.isEnabled = true
                self.cancelButton.isHidden = true
                self.subjects = outcome.subjects
                self.selectedIndex = 0

                if self.subjects.isEmpty {
                    self.rebuildResults()
                    self.rebuildEpisodes()
                    self.setContentVisible(false)
                    let failureDetail = self.failureSummary(outcome.failures)
                    self.showState(
                        title: NSLocalizedString("没有找到相关作品", comment: ""),
                        detail: failureDetail.isEmpty
                            ? NSLocalizedString("换一个关键词，或检查源是否可用", comment: "")
                            : failureDetail,
                        actionTitle: NSLocalizedString("源管理", comment: ""),
                        onAction: { [weak self] in
                            self?.showSourceSettings()
                        }
                    )
                    self.summaryLabel.text = String(
                        format: NSLocalizedString("%d 个源参与搜索", comment: ""),
                        outcome.sourceCount
                    )
                    return
                }

                self.rebuildResults()
                self.setContentVisible(true)
                self.stateView.isHidden = true
                self.updateSearchSummary(outcome)
                self.loadEpisodesForSelection()
            } catch {
                guard !Task.isCancelled else { return }
                self.isSearching = false
                self.searchButton.isEnabled = true
                self.cancelButton.isHidden = true
                self.subjects = []
                self.episodes = []
                self.rebuildResults()
                self.rebuildEpisodes()
                self.setContentVisible(false)
                self.showState(
                    title: NSLocalizedString("搜索失败", comment: ""),
                    detail: error.localizedDescription,
                    actionTitle: NSLocalizedString("重试", comment: ""),
                    onAction: { [weak self] in
                        self?.startSearch()
                    }
                )
            }
        }
    }

    private func cancelSearch() {
        searchTask?.cancel()
        episodesTask?.cancel()
        isSearching = false
        busyEpisodeID = nil
        searchButton.isEnabled = true
        cancelButton.isHidden = true
        if subjects.isEmpty {
            showIdleState()
        } else {
            rebuildEpisodes()
            stateView.isHidden = true
        }
        summaryLabel.text = NSLocalizedString("已取消", comment: "")
    }

    private func updateSearchSummary(_ outcome: OnlineSearchOutcome) {
        var text = String(
            format: NSLocalizedString("共 %d 个结果 · %d 个源", comment: ""),
            outcome.subjects.count,
            outcome.sourceCount
        )
        if !outcome.failures.isEmpty {
            text += String(
                format: NSLocalizedString(" · %d 个源失败", comment: ""),
                outcome.failures.count
            )
        }
        summaryLabel.text = text
        summaryLabel.toolTip = failureSummary(outcome.failures)
    }

    private func failureSummary(_ failures: [String: String]) -> String {
        return failures
            .sorted { $0.key < $1.key }
            .prefix(4)
            .map { "\($0.key)：\($0.value)" }
            .joined(separator: "\n")
    }

    /// 源管理里置顶/取消置顶后，当前搜索结果立即按置顶优先重排。
    private func applyPinOrderToSubjects() {
        guard !subjects.isEmpty else { return }
        let currentID = subjects.indices.contains(selectedIndex) ? subjects[selectedIndex].id : nil
        let pinned = Set(OnlineSourcePreferences.pinnedSourceIDs)
        subjects = subjects.enumerated().sorted { lhs, rhs in
            let lhsPinned = pinned.contains(lhs.element.sourceID)
            let rhsPinned = pinned.contains(rhs.element.sourceID)
            if lhsPinned != rhsPinned {
                return lhsPinned
            }
            return lhs.offset < rhs.offset
        }.map { $0.element }
        if let currentID, let index = subjects.firstIndex(where: { $0.id == currentID }) {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }
        rebuildResults()
    }

    // MARK: Episodes

    private func loadEpisodesForSelection() {
        episodesTask?.cancel()
        episodes = []
        rebuildEpisodes()
        guard selectedIndex < subjects.count else { return }

        let subject = subjects[selectedIndex]
        guard let source = allSources.first(where: { $0.id == subject.sourceID }) else {
            episodesTitle.text = NSLocalizedString("剧集列表", comment: "")
            episodes = []
            rebuildEpisodes(message: NSLocalizedString("源配置已变化，请重新搜索", comment: ""))
            return
        }

        episodesTitle.text = String(
            format: NSLocalizedString("剧集 · %@", comment: ""),
            subject.title
        )
        episodes = []
        rebuildEpisodes(message: NSLocalizedString("正在解析剧集…", comment: ""))

        episodesTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let list = try await self.service.loadEpisodes(source: source, subject: subject)
                guard !Task.isCancelled else { return }
                self.episodes = list
                self.rebuildEpisodes(
                    message: list.isEmpty
                        ? NSLocalizedString("没有解析到剧集，可尝试在浏览器打开作品页", comment: "")
                        : nil
                )
            } catch {
                guard !Task.isCancelled else { return }
                self.episodes = []
                self.rebuildEpisodes(
                    message: String(
                        format: NSLocalizedString("剧集解析失败：%@", comment: ""),
                        error.localizedDescription
                    ),
                    browserURL: subject.url
                )
            }
        }
    }

    // MARK: Playback

    private func play(_ episode: OnlineEpisode) {
        guard selectedIndex < subjects.count else { return }
        let subject = subjects[selectedIndex]
        guard let source = allSources.first(where: { $0.id == subject.sourceID }) else { return }
        guard let startIndex = episodes.firstIndex(where: { $0.id == episode.id }) else { return }
        let orderedEpisodes = episodes
        let lookahead = OnlineSourcePreferences.continuousPlayback
            ? OnlinePlaybackService.continuousLookahead
            : 0

        playbackTask?.cancel()
        playbackTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            let allowed = await self.entitlementGate.require(
                .member,
                feature: .onlinePlayback,
                presenting: self.view.window
            )
            guard allowed else { return }

            self.busyEpisodeID = episode.id
            self.rebuildEpisodes()
            self.summaryLabel.text = NSLocalizedString("正在解析视频地址…", comment: "")

            do {
                let preparation = try await self.service.preparePlaylist(
                    source: source,
                    subject: subject,
                    episodes: orderedEpisodes,
                    startIndex: startIndex,
                    lookahead: lookahead,
                    progress: { message in
                        DispatchQueue.main.async {
                            self.summaryLabel.text = message
                        }
                    }
                )
                guard !Task.isCancelled else { return }
                guard let startFile = preparation.files.first else {
                    throw OnlinePlaybackError.videoNotFound(episode.url)
                }
                self.busyEpisodeID = nil
                self.rebuildEpisodes()
                self.updateSourceSummary()
                self.router?.play(files: preparation.files, startWith: startFile, progress: nil)

                if preparation.files.count > 1 {
                    var text = String(
                        format: NSLocalizedString("连续播放：已准备 %d 集", comment: ""),
                        preparation.files.count
                    )
                    if preparation.skippedCount > 0 {
                        text += String(
                            format: NSLocalizedString("，跳过 %d 集", comment: ""),
                            preparation.skippedCount
                        )
                    }
                    self.summaryLabel.text = text
                } else if lookahead > 0, startIndex + 1 < orderedEpisodes.count {
                    self.summaryLabel.text = NSLocalizedString(
                        "后续剧集解析失败，仅播放当前集",
                        comment: ""
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.busyEpisodeID = nil
                self.rebuildEpisodes()
                self.updateSourceSummary()
                self.showPlaybackError(error, episode: episode)
            }
        }
    }

    private func showPlaybackError(_ error: Error, episode: OnlineEpisode) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("在线播放失败", comment: "")
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: NSLocalizedString("重试当前集", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("在浏览器打开", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.play(episode)
            } else if response == .alertSecondButtonReturn {
                NSWorkspace.shared.open(episode.url)
            }
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }

    // MARK: States

    private func showInitialState() {
        let loggedIn = AccessTokenHolder.shared.current() != nil
        isLoggedIn = loggedIn
        if loggedIn {
            showIdleState()
        } else {
            showLoginState()
        }
    }

    private func showIdleState() {
        subjects = []
        episodes = []
        selectedIndex = 0
        rebuildResults()
        rebuildEpisodes()
        setContentVisible(false)
        if allSources.isEmpty {
            showState(
                title: NSLocalizedString("在线源未加载", comment: ""),
                detail: NSLocalizedString("打开源管理检查配置", comment: ""),
                actionTitle: NSLocalizedString("源管理", comment: ""),
                onAction: { [weak self] in
                    self?.showSourceSettings()
                }
            )
        } else {
            showState(
                title: NSLocalizedString("输入关键词开始搜索", comment: ""),
                detail: NSLocalizedString("搜索免费；播放需要弹弹play会员", comment: "")
            )
            updateSourceSummary()
        }
    }

    private func showLoginState() {
        subjects = []
        episodes = []
        selectedIndex = 0
        rebuildResults()
        rebuildEpisodes()
        setContentVisible(false)
        showState(
            title: NSLocalizedString("登录后使用在线观看", comment: ""),
            detail: NSLocalizedString("搜索与播放需要弹弹play账号", comment: ""),
            actionTitle: NSLocalizedString("登录", comment: ""),
            onAction: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    _ = await LoginGate.shared.ensureLoggedIn(presenting: self.view.window)
                }
            }
        )
        stateView.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineLogin)
    }

    private func showState(
        title: String,
        detail: String? = nil,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        stateView.isHidden = false
        stateView.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineStatus)
        stateView.configure(
            title: title,
            detail: detail,
            actionTitle: actionTitle,
            onAction: onAction
        )
    }

    private func setContentVisible(_ visible: Bool) {
        resultsTitle.isHidden = !visible
        episodesTitle.isHidden = !visible
        resultsScroll.isHidden = !visible
        episodesScroll.isHidden = !visible
    }

    // MARK: Rows

    private func rebuildResults() {
        clear(stack: resultsScroll.stack)

        guard !subjects.isEmpty else {
            resultsScroll.layoutContent()
            return
        }

        for (index, subject) in subjects.enumerated() {
            let row = WelcomeShellOnlineResultRowView()
            row.configure(with: subject)
            row.isSelectedResult = (index == selectedIndex)
            row.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.onlineResults).\(index)")
            row.onClick = { [weak self] in
                guard let self = self else { return }
                self.selectedIndex = index
                self.rebuildResults()
                self.loadEpisodesForSelection()
            }
            resultsScroll.stack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.width.equalTo(resultsScroll.stack)
            }
        }
        resultsScroll.layoutContent()
    }

    private func rebuildEpisodes(message: String? = nil, browserURL: URL? = nil) {
        clear(stack: episodesScroll.stack)

        if let message {
            let label = welcomeShellLabel(
                message,
                font: .systemFont(ofSize: 12),
                color: .secondaryLabelColor,
                lines: 3,
                lineBreakMode: .byWordWrapping
            )
            episodesScroll.stack.addArrangedSubview(label)
            label.snp.makeConstraints { make in
                make.width.equalTo(episodesScroll.stack)
            }
            if let browserURL {
                let button = WelcomeShellClosureButton(title: NSLocalizedString("在浏览器打开作品页", comment: ""))
                button.bezelStyle = .rounded
                button.controlSize = .small
                button.onClick = {
                    NSWorkspace.shared.open(browserURL)
                }
                episodesScroll.stack.addArrangedSubview(button)
            }
            episodesScroll.layoutContent()
            return
        }

        guard selectedIndex < subjects.count else {
            episodesScroll.layoutContent()
            return
        }

        let subject = subjects[selectedIndex]
        if episodes.isEmpty {
            let label = welcomeShellLabel(
                NSLocalizedString("暂无剧集", comment: ""),
                font: .systemFont(ofSize: 12),
                color: .secondaryLabelColor
            )
            episodesScroll.stack.addArrangedSubview(label)
            label.snp.makeConstraints { make in
                make.width.equalTo(episodesScroll.stack)
            }
            episodesScroll.layoutContent()
            return
        }

        for (index, episode) in episodes.enumerated() {
            let row = WelcomeShellOnlineEpisodeRowView()
            row.configure(episode: episode, subject: subject, index: index)
            row.setBusy(busyEpisodeID == episode.id)
            row.onPlay = { [weak self] in
                self?.play(episode)
            }
            row.onOpen = {
                NSWorkspace.shared.open(episode.url)
            }
            row.onCopy = {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(episode.url.absoluteString, forType: .string)
            }
            episodesScroll.stack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.width.equalTo(episodesScroll.stack)
            }
        }
        episodesScroll.layoutContent()
    }

    private func clear(stack: NSStackView) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    // MARK: Source settings

    private func showSourceSettings() {
        sourceSettingsPanel?.close()

        let controller = OnlineSourceSettingsViewController(sources: allSources)
        controller.onSourcesChanged = { [weak self] sources in
            guard let self = self else { return }
            self.allSources = sources
            self.updateSourceSummary()
            if !self.lastKeyword.isEmpty {
                self.startSearch()
            } else if self.subjects.isEmpty {
                self.showIdleState()
            }
        }
        controller.onPinsChanged = { [weak self] in
            self?.applyPinOrderToSubjects()
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = NSLocalizedString("在线源管理", comment: "")
        panel.isReleasedWhenClosed = false
        panel.contentViewController = controller
        panel.delegate = self
        sourceSettingsPanel = panel

        if let window = view.window {
            window.beginSheet(panel)
        } else {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel,
              panel == sourceSettingsPanel else { return }
        sourceSettingsPanel = nil
    }

    // MARK: WelcomeShellLoginAware

    func welcomeShellLoginStateDidChange() {
        let loggedIn = AccessTokenHolder.shared.current() != nil
        isLoggedIn = loggedIn
        guard loggedIn else {
            showLoginState()
            return
        }
        if allSources.isEmpty {
            loadSources()
        } else if lastKeyword.isEmpty {
            showIdleState()
        } else {
            startSearch()
        }
    }
}

// MARK: - Source settings

final class OnlineSourceSettingsViewController: ViewController {

    private var sources: [OnlineMediaSource]
    var onSourcesChanged: (([OnlineMediaSource]) -> Void)?
    var onPinsChanged: (() -> Void)?

    private let sourceStore = OnlineSourceStore.shared
    private let service = OnlinePlaybackService.shared

    private let animekoField = NSTextField()
    private let kazumiField = NSTextField()
    private let sourceScroll = WelcomeShellStackScrollView()
    private let statusLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor,
        lines: 3,
        lineBreakMode: .byWordWrapping
    )
    private let spinner = NSProgressIndicator()
    private lazy var saveButton = WelcomeShellClosureButton(title: NSLocalizedString("保存并刷新", comment: ""))
    private lazy var closeButton = WelcomeShellClosureButton(title: NSLocalizedString("完成", comment: ""))
    private lazy var resetButton = WelcomeShellClosureButton(title: NSLocalizedString("恢复默认地址", comment: ""))
    private lazy var clearButton = WelcomeShellClosureButton(title: NSLocalizedString("清空缓存", comment: ""))

    init(sources: [OnlineMediaSource]) {
        self.sources = sources
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 640))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        animekoField.stringValue = OnlineSourcePreferences.animekoURL
        kazumiField.stringValue = OnlineSourcePreferences.kazumiURL
        rebuildSourceList()
        updateStatus()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        sourceScroll.layoutContent()
    }

    private func setup() {
        let titleLabel = welcomeShellLabel(
            NSLocalizedString("在线源管理", comment: ""),
            font: .systemFont(ofSize: 18, weight: .bold),
            color: .labelColor
        )
        let detailLabel = welcomeShellLabel(
            NSLocalizedString("源配置只保存在本机；App 不内置第三方站点。更新失败时会继续使用本地缓存。", comment: ""),
            font: .systemFont(ofSize: 11),
            color: .secondaryLabelColor,
            lines: 3,
            lineBreakMode: .byWordWrapping
        )

        let animekoLabel = welcomeShellLabel(
            "Animeko css1.json",
            font: .systemFont(ofSize: 11, weight: .medium),
            color: .labelColor
        )
        let kazumiLabel = welcomeShellLabel(
            "Kazumi index.json",
            font: .systemFont(ofSize: 11, weight: .medium),
            color: .labelColor
        )
        animekoField.placeholderString = OnlineSourcePreferences.defaultAnimekoURL
        kazumiField.placeholderString = OnlineSourcePreferences.defaultKazumiURL
        animekoField.font = .systemFont(ofSize: 11)
        kazumiField.font = .systemFont(ofSize: 11)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.isHidden = true

        saveButton.bezelStyle = .rounded
        saveButton.onClick = { [weak self] in
            self?.saveAndRefresh()
        }
        closeButton.bezelStyle = .rounded
        closeButton.onClick = { [weak self] in
            self?.closePanel()
        }
        resetButton.bezelStyle = .rounded
        resetButton.controlSize = .small
        resetButton.onClick = { [weak self] in
            OnlineSourcePreferences.resetURLs()
            self?.animekoField.stringValue = OnlineSourcePreferences.animekoURL
            self?.kazumiField.stringValue = OnlineSourcePreferences.kazumiURL
        }
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        clearButton.onClick = { [weak self] in
            self?.clearCache()
        }

        let buttonRow = NSStackView(views: [resetButton, clearButton, NSView(), spinner, closeButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        sourceScroll.hasVerticalScroller = true
        sourceScroll.hasHorizontalScroller = false
        sourceScroll.autohidesScrollers = true
        sourceScroll.drawsBackground = false
        sourceScroll.borderType = .noBorder
        sourceScroll.snp.makeConstraints { make in
            make.height.equalTo(210)
        }

        let sourceTitle = welcomeShellLabel(
            NSLocalizedString("已加载的源", comment: ""),
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: .labelColor
        )

        view.addSubview(titleLabel)
        view.addSubview(detailLabel)
        view.addSubview(animekoLabel)
        view.addSubview(animekoField)
        view.addSubview(kazumiLabel)
        view.addSubview(kazumiField)
        view.addSubview(sourceTitle)
        view.addSubview(sourceScroll)
        view.addSubview(statusLabel)
        view.addSubview(buttonRow)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(22)
            make.trailing.equalToSuperview().offset(-22)
        }
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.trailing.equalTo(titleLabel)
        }
        animekoLabel.snp.makeConstraints { make in
            make.top.equalTo(detailLabel.snp.bottom).offset(14)
            make.leading.equalTo(titleLabel)
        }
        animekoField.snp.makeConstraints { make in
            make.top.equalTo(animekoLabel.snp.bottom).offset(4)
            make.leading.trailing.equalTo(titleLabel)
        }
        kazumiLabel.snp.makeConstraints { make in
            make.top.equalTo(animekoField.snp.bottom).offset(10)
            make.leading.equalTo(titleLabel)
        }
        kazumiField.snp.makeConstraints { make in
            make.top.equalTo(kazumiLabel.snp.bottom).offset(4)
            make.leading.trailing.equalTo(titleLabel)
        }
        sourceTitle.snp.makeConstraints { make in
            make.top.equalTo(kazumiField.snp.bottom).offset(14)
            make.leading.equalTo(titleLabel)
        }
        sourceScroll.snp.makeConstraints { make in
            make.top.equalTo(sourceTitle.snp.bottom).offset(6)
            make.leading.trailing.equalTo(titleLabel)
        }
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(sourceScroll.snp.bottom).offset(8)
            make.leading.trailing.equalTo(titleLabel)
        }
        buttonRow.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-18)
        }
    }

    private func rebuildSourceList() {
        sourceScroll.stack.arrangedSubviews.forEach {
            sourceScroll.stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !sources.isEmpty else {
            let label = welcomeShellLabel(
                NSLocalizedString("还没有加载到源，点击“保存并刷新”。", comment: ""),
                font: .systemFont(ofSize: 11),
                color: .secondaryLabelColor
            )
            sourceScroll.stack.addArrangedSubview(label)
            label.snp.makeConstraints { make in
                make.width.equalTo(sourceScroll.stack)
            }
            sourceScroll.layoutContent()
            return
        }

        for source in sources {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8

            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(sourceToggled(_:)))
            checkbox.state = OnlineSourcePreferences.isSourceEnabled(source.id) ? .on : .off
            checkbox.identifier = NSUserInterfaceItemIdentifier(source.id)
            checkbox.setAccessibilityLabel(source.name)

            let isPinned = OnlineSourcePreferences.isSourcePinned(source.id)
            let pinButton = WelcomeShellClosureButton()
            pinButton.bezelStyle = .inline
            pinButton.isBordered = false
            pinButton.image = welcomeShellSymbol(isPinned ? "star.fill" : "star", pointSize: 12, weight: .medium)
            pinButton.imagePosition = .imageOnly
            pinButton.contentTintColor = isPinned ? .systemYellow : .secondaryLabelColor
            pinButton.toolTip = isPinned
                ? NSLocalizedString("取消置顶", comment: "")
                : NSLocalizedString("置顶该源", comment: "")
            pinButton.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.onlineSourcePin).\(source.id)")
            pinButton.setAccessibilityLabel(pinButton.toolTip)
            pinButton.onClick = { [weak self] in
                self?.togglePin(source.id)
            }

            let name = welcomeShellLabel(
                source.name,
                font: .systemFont(ofSize: 11.5, weight: .medium),
                color: .labelColor
            )
            let pinBadge = welcomeShellLabel(
                NSLocalizedString("置顶", comment: ""),
                font: .systemFont(ofSize: 9.5, weight: .semibold),
                color: .mainColor
            )
            pinBadge.isHidden = !isPinned
            let detailText = source.detail.isEmpty
                ? source.engine.displayName
                : "\(source.engine.displayName) · \(source.detail)"
            let detail = welcomeShellLabel(
                detailText,
                font: .systemFont(ofSize: 10),
                color: .tertiaryLabelColor
            )

            row.addArrangedSubview(checkbox)
            row.addArrangedSubview(pinButton)
            row.addArrangedSubview(name)
            row.addArrangedSubview(pinBadge)
            row.addArrangedSubview(detail)
            sourceScroll.stack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.width.equalTo(sourceScroll.stack)
            }
        }
        sourceScroll.layoutContent()
    }

    private func togglePin(_ id: String) {
        let pinned = OnlineSourcePreferences.toggleSourcePinned(id)
        if pinned {
            updateStatus(NSLocalizedString("已置顶，搜索结果将优先显示该源。", comment: ""))
        } else {
            updateStatus(NSLocalizedString("已取消置顶。", comment: ""))
        }
        onPinsChanged?()
        // 按钮正在处理点击事件，延后重建整行，避免在 action 中释放 sender。
        DispatchQueue.main.async { [weak self] in
            self?.rebuildSourceList()
        }
    }

    @objc private func sourceToggled(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        OnlineSourcePreferences.setSource(id, enabled: sender.state == .on)
        updateStatus()
    }

    private func updateStatus(_ message: String? = nil) {
        if let message {
            statusLabel.text = message
            return
        }
        let enabled = sources.filter { OnlineSourcePreferences.isSourceEnabled($0.id) }.count
        statusLabel.text = String(
            format: NSLocalizedString("共 %d 个源，已启用 %d 个", comment: ""),
            sources.count,
            enabled
        )
    }

    private func setBusy(_ busy: Bool) {
        spinner.isHidden = !busy
        if busy {
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
        saveButton.isEnabled = !busy
        closeButton.isEnabled = !busy
        resetButton.isEnabled = !busy
        clearButton.isEnabled = !busy
    }

    private func saveAndRefresh() {
        let animeko = animekoField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let kazumi = kazumiField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let animekoURL = URL(string: animeko),
              let animekoScheme = animekoURL.scheme?.lowercased(),
              animekoScheme == "http" || animekoScheme == "https",
              animekoURL.host != nil else {
            updateStatus(NSLocalizedString("Animeko 地址无效，需要 http/https URL。", comment: ""))
            return
        }
        guard let kazumiURL = URL(string: kazumi),
              let kazumiScheme = kazumiURL.scheme?.lowercased(),
              kazumiScheme == "http" || kazumiScheme == "https",
              kazumiURL.host != nil else {
            updateStatus(NSLocalizedString("Kazumi 地址无效，需要 http/https URL。", comment: ""))
            return
        }

        setBusy(true)
        updateStatus(NSLocalizedString("正在保存并刷新源配置…", comment: ""))

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                await self.sourceStore.updateURLs(animeko: animeko, kazumi: kazumi)
                // 保留旧缓存用于网络失败回退；需要强制重下时用户可点“清空缓存”。
                let loaded = try await self.service.loadSources(
                    forceRefresh: true,
                    progress: { message in
                        DispatchQueue.main.async { [weak self] in
                            self?.updateStatus(message)
                        }
                    }
                )
                self.sources = loaded
                self.rebuildSourceList()
                self.updateStatus(String(
                    format: NSLocalizedString("刷新完成，共 %d 个源。", comment: ""),
                    loaded.count
                ))
                self.setBusy(false)
                self.onSourcesChanged?(loaded)
            } catch {
                self.setBusy(false)
                self.updateStatus(String(
                    format: NSLocalizedString("刷新失败：%@", comment: ""),
                    error.localizedDescription
                ))
            }
        }
    }

    private func clearCache() {
        setBusy(true)
        updateStatus(NSLocalizedString("正在清空缓存…", comment: ""))
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.sourceStore.clearCache()
            self.sources = []
            self.rebuildSourceList()
            self.setBusy(false)
            self.updateStatus(NSLocalizedString("缓存已清空，点击“保存并刷新”重新下载。", comment: ""))
        }
    }

    private func closePanel() {
        guard let panel = view.window else { return }
        if let parent = panel.sheetParent {
            parent.endSheet(panel)
        } else {
            panel.close()
        }
    }
}
