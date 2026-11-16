//
//  WelcomeOnlineViewController.swift
//  AniXPlayer
//
//  macOS：欢迎页在线观看首版（关键词搜索 + 结果 + 剧集 + 浏览器打开/复制链接）。
//  不实现网页嗅探、内嵌网页或第三方站点登录。
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
        let width = documentContentView.bounds.width
        guard width > 0 else { return }
        if documentContentView.frame.width != width {
            documentContentView.frame.size.width = width
            documentContentView.layoutSubtreeIfNeeded()
        }
        let height = max(stack.fittingSize.height + 12, documentContentView.bounds.height)
        if abs(documentContentView.frame.height - height) > 0.5 {
            documentContentView.frame.size.height = height
        }
    }
}

// MARK: - Result row

final class WelcomeShellOnlineResultRowView: WelcomeShellTapView {

    private let titleLabel = welcomeShellLabel("", font: .systemFont(ofSize: 13, weight: .semibold), color: .labelColor, lines: 2, lineBreakMode: .byWordWrapping)
    private let detailLabel = welcomeShellLabel("", font: .systemFont(ofSize: 11), color: .secondaryLabelColor)

    var isSelectedResult = false {
        didSet { updateSelectedStyle() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalBackground = .clear
        layer?.cornerRadius = 7

        addSubview(titleLabel)
        addSubview(detailLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
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

    func configure(with collection: SearchCollection) {
        titleLabel.text = collection.animeTitle
        let type = collection.typeDescription.isEmpty ? collection.type.displayName : collection.typeDescription
        detailLabel.text = String(
            format: NSLocalizedString("%@ · %d 集", comment: ""),
            type,
            collection.collection.count
        )
        setAccessibilityLabel("\(collection.animeTitle)，\(detailLabel.text ?? "")")
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

    private let titleLabel = welcomeShellLabel("", font: .systemFont(ofSize: 12.5, weight: .medium), color: .labelColor)
    private let idLabel = welcomeShellLabel("", font: .systemFont(ofSize: 10.5), color: .tertiaryLabelColor)
    private let openButton = WelcomeShellClosureButton(title: NSLocalizedString("在浏览器搜索", comment: ""))
    private let copyButton = WelcomeShellClosureButton(title: NSLocalizedString("复制搜索链接", comment: ""))

    var onOpen: (() -> Void)?
    var onCopy: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        updateColors()

        openButton.bezelStyle = .rounded
        openButton.controlSize = .mini
        openButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineOpenBrowser)
        openButton.onClick = { [weak self] in
            self?.onOpen?()
        }

        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .mini
        copyButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineCopyLink)
        copyButton.onClick = { [weak self] in
            self?.onCopy?()
        }

        addSubview(titleLabel)
        addSubview(idLabel)
        addSubview(openButton)
        addSubview(copyButton)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(10)
            make.trailing.lessThanOrEqualTo(openButton.snp.leading).offset(-8)
        }
        idLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-10)
        }
        copyButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
        openButton.snp.makeConstraints { make in
            make.trailing.equalTo(copyButton.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
        }
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(52)
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

    func configure(episode: Search, animeTitle: String) {
        titleLabel.text = episode.episodeTitle
        idLabel.text = String(format: NSLocalizedString("剧集 ID %d", comment: ""), episode.id)
        setAccessibilityLabel("\(animeTitle)，\(episode.episodeTitle)")
    }
}

// MARK: - Online page

final class WelcomeOnlineViewController: ViewController, WelcomeShellLoginAware {

    weak var router: WelcomeShellRouting?

    private let service = HomePageService()
    private var results: [SearchCollection] = []
    private var selectedIndex = 0
    private var searchTask: Task<Void, Never>?
    private var lastKeyword = ""
    private var isLoggedIn = false

    // MARK: Views

    private lazy var headerView: WelcomeShellPageHeaderView = {
        return WelcomeShellPageHeaderView(
            title: NSLocalizedString("在线观看", comment: ""),
            subtitle: NSLocalizedString("搜索弹弹play剧集资源", comment: "")
        )
    }()

    private lazy var searchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = NSLocalizedString("输入番剧或剧集关键词", comment: "")
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

    private let infoBanner = NSView()
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
        showInitialState()
    }

    deinit {
        searchTask?.cancel()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        resultsScroll.layoutContent()
        episodesScroll.layoutContent()
    }

    // MARK: Layout

    private func setupLayout() {
        searchField.snp.makeConstraints { make in
            make.width.equalTo(280)
        }

        let searchRow = NSStackView(views: [searchField, searchButton, NSView()])
        searchRow.orientation = .horizontal
        searchRow.alignment = .centerY
        searchRow.spacing = 8

        infoBanner.wantsLayer = true
        infoBanner.layer?.cornerRadius = 8
        infoBanner.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.12).cgColor
        infoBanner.layer?.borderWidth = 1
        infoBanner.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.30).cgColor

        let infoIcon = ImageView()
        infoIcon.image = welcomeShellSymbol("info.circle", pointSize: 13, weight: .medium)
        infoIcon.contentTintColor = .systemOrange
        infoIcon.setScaling(.aspectFit)
        let infoLabel = welcomeShellLabel(
            NSLocalizedString("在线播放源未配置，当前只展示弹弹play剧集搜索结果", comment: ""),
            font: .systemFont(ofSize: 11.5),
            color: .secondaryLabelColor
        )
        infoBanner.addSubview(infoIcon)
        infoBanner.addSubview(infoLabel)
        infoIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
        infoLabel.snp.makeConstraints { make in
            make.leading.equalTo(infoIcon.snp.trailing).offset(7)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }
        infoBanner.snp.makeConstraints { make in
            make.height.equalTo(32)
        }

        let content = NSStackView(views: [resultsColumn(), episodesColumn()])
        content.orientation = .horizontal
        content.alignment = .top
        content.spacing = 14
        content.distribution = .fill

        view.addSubview(headerView)
        view.addSubview(searchRow)
        view.addSubview(infoBanner)
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
        infoBanner.snp.makeConstraints { make in
            make.top.equalTo(searchRow.snp.bottom).offset(8)
            make.leading.trailing.equalTo(headerView)
        }
        summaryLabel.snp.makeConstraints { make in
            make.top.equalTo(infoBanner.snp.bottom).offset(8)
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

    // MARK: Search

    @objc private func startSearch() {
        let keyword = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            stateView.isHidden = false
            stateView.configure(title: NSLocalizedString("请输入搜索关键词", comment: ""))
            return
        }
        lastKeyword = keyword

        searchTask?.cancel()
        showLoadingState()

        searchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard AccessTokenHolder.shared.current() != nil else {
                self.isLoggedIn = false
                self.showLoginState()
                return
            }
            self.isLoggedIn = true

            do {
                let result = try await self.service.loadSearchEpisodes(keyword: keyword)
                guard !Task.isCancelled else { return }
                self.results = result.collection
                self.selectedIndex = 0
                self.rebuildResults()
                self.rebuildEpisodes()
                self.stateView.isHidden = !self.results.isEmpty
                self.setContentVisible(!self.results.isEmpty)
                if self.results.isEmpty {
                    self.stateView.configure(
                        title: NSLocalizedString("没有找到相关剧集", comment: ""),
                        detail: NSLocalizedString("换一个关键词试试", comment: "")
                    )
                    self.summaryLabel.text = ""
                } else {
                    self.summaryLabel.text = String(
                        format: NSLocalizedString("共 %d 个结果", comment: ""),
                        self.results.count
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.results = []
                self.rebuildResults()
                self.rebuildEpisodes()
                self.summaryLabel.text = ""
                self.stateView.isHidden = false
                self.setContentVisible(false)
                self.stateView.configure(
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
        results = []
        selectedIndex = 0
        rebuildResults()
        rebuildEpisodes()
        summaryLabel.text = ""
        stateView.isHidden = false
        setContentVisible(false)
        stateView.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineStatus)
        stateView.configure(
            title: NSLocalizedString("输入关键词开始搜索", comment: ""),
            detail: NSLocalizedString("搜索结果会显示在这里", comment: "")
        )
    }

    private func setContentVisible(_ visible: Bool) {
        resultsTitle.isHidden = !visible
        episodesTitle.isHidden = !visible
        resultsScroll.isHidden = !visible
        episodesScroll.isHidden = !visible
    }

    private func showLoadingState() {
        results = []
        selectedIndex = 0
        rebuildResults()
        rebuildEpisodes()
        summaryLabel.text = ""
        stateView.isHidden = false
        setContentVisible(false)
        stateView.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.onlineStatus)
        stateView.configure(title: NSLocalizedString("正在搜索…", comment: ""))
    }

    private func showLoginState() {
        results = []
        selectedIndex = 0
        rebuildResults()
        rebuildEpisodes()
        summaryLabel.text = ""
        stateView.isHidden = false
        setContentVisible(false)
        stateView.configure(
            title: NSLocalizedString("登录后使用在线搜索", comment: ""),
            detail: NSLocalizedString("在线观看需要登录弹弹play账号", comment: ""),
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

    private func rebuildResults() {
        resultsScroll.stack.arrangedSubviews.forEach {
            resultsScroll.stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for (index, collection) in results.enumerated() {
            let row = WelcomeShellOnlineResultRowView()
            row.configure(with: collection)
            row.isSelectedResult = (index == selectedIndex)
            row.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.onlineResults).\(index)")
            row.onClick = { [weak self] in
                guard let self = self else { return }
                self.selectedIndex = index
                self.rebuildResults()
                self.rebuildEpisodes()
            }
            resultsScroll.stack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.width.equalTo(resultsScroll.stack)
            }
        }
        resultsScroll.layoutContent()
    }

    private func rebuildEpisodes() {
        episodesScroll.stack.arrangedSubviews.forEach {
            episodesScroll.stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard selectedIndex < results.count else {
            episodesTitle.text = NSLocalizedString("剧集列表", comment: "")
            episodesScroll.layoutContent()
            return
        }

        let collection = results[selectedIndex]
        episodesTitle.text = String(
            format: NSLocalizedString("剧集列表 · %@", comment: ""),
            collection.animeTitle
        )

        guard !collection.collection.isEmpty else {
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

        for episode in collection.collection {
            let row = WelcomeShellOnlineEpisodeRowView()
            row.configure(episode: episode, animeTitle: collection.animeTitle)
            row.onOpen = { [weak self] in
                self?.openWebSearch(for: collection)
            }
            row.onCopy = { [weak self] in
                self?.copyWebSearchLink(for: collection)
            }
            episodesScroll.stack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.width.equalTo(episodesScroll.stack)
            }
        }
        episodesScroll.layoutContent()
    }

    private func webSearchURL(for collection: SearchCollection) -> URL? {
        var components = URLComponents(string: "https://www.dandanplay.com/search")
        components?.queryItems = [URLQueryItem(name: "keyword", value: collection.animeTitle)]
        return components?.url
    }

    private func openWebSearch(for collection: SearchCollection) {
        guard let url = webSearchURL(for: collection) else { return }
        NSWorkspace.shared.open(url)
    }

    private func copyWebSearchLink(for collection: SearchCollection) {
        guard let url = webSearchURL(for: collection) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        view.show(text: NSLocalizedString("已复制搜索链接", comment: ""))
    }

    // MARK: WelcomeShellLoginAware

    func welcomeShellLoginStateDidChange() {
        if !lastKeyword.isEmpty {
            startSearch()
            return
        }
        let loggedIn = AccessTokenHolder.shared.current() != nil
        isLoggedIn = loggedIn
        if loggedIn {
            showIdleState()
        } else {
            showLoginState()
        }
    }
}
