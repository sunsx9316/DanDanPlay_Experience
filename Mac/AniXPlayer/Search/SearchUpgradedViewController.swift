//
//  SearchUpgradedViewController.swift
//  AniXPlayer
//
//  macOS：搜索升级页面。
//  动画 / 剧集 / 标签 / 高级搜索统一入口，结果可进入 BangumiDetailViewController。
//

import Cocoa
import SnapKit
import Kingfisher
import ANXLog

// MARK: - 结果节点

final class SearchUpgradeResultNode: NSObject {
    let animeId: Int
    let title: String
    let detail: String
    let rating: Double
    let imageUrl: String
    let isEpisode: Bool
    var children: [SearchUpgradeResultNode]

    init(
        animeId: Int,
        title: String,
        detail: String,
        rating: Double = 0,
        imageUrl: String = "",
        isEpisode: Bool = false,
        children: [SearchUpgradeResultNode] = []
    ) {
        self.animeId = animeId
        self.title = title
        self.detail = detail
        self.rating = rating
        self.imageUrl = imageUrl
        self.isEpisode = isEpisode
        self.children = children
    }
}

// MARK: - 结果 Cell

final class SearchUpgradeResultCellView: NSView {

    private lazy var coverImageView: ImageView = {
        let view = ImageView()
        view.setScaling(.aspectFill)
        view.wantsLayer = true
        view.layer?.cornerRadius = 4
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        return view
    }()

    private lazy var titleLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_normal()
        label.textColor = .textColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }()

    private lazy var detailLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        return label
    }()

    private lazy var ratingLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_normal(weight: .semibold)
        label.textColor = .mainColor
        label.alignment = .right
        return label
    }()

    private lazy var ratingFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(coverImageView)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(ratingLabel)

        coverImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.equalTo(44)
            make.height.equalTo(58)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(9)
            make.trailing.equalTo(ratingLabel.snp.leading).offset(-8)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.trailing.equalTo(ratingLabel.snp.leading).offset(-8)
        }
        ratingLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(48)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(node: SearchUpgradeResultNode) {
        titleLabel.text = node.title
        titleLabel.font = node.children.isEmpty ? .ddp_normal() : .ddp_normal(weight: .semibold)
        detailLabel.text = node.detail

        if node.imageUrl.isEmpty {
            coverImageView.kf.cancelDownloadTask()
            coverImageView.image = nil
            coverImageView.isHidden = true
        } else {
            coverImageView.isHidden = false
            coverImageView.kf.setImage(with: URL(string: node.imageUrl))
        }

        if node.rating > 0 {
            ratingLabel.font = .ddp_normal(weight: .semibold)
            ratingLabel.textColor = .mainColor
            ratingLabel.text = ratingFormatter.string(from: NSNumber(value: node.rating))
            ratingLabel.isHidden = false
        } else {
            ratingLabel.text = node.isEpisode ? NSLocalizedString("剧集", comment: "") : ""
            ratingLabel.font = node.isEpisode ? .ddp_small() : .ddp_normal(weight: .semibold)
            ratingLabel.textColor = node.isEpisode ? .subtitleTextColor : .mainColor
            ratingLabel.isHidden = ratingLabel.text?.isEmpty ?? true
        }
    }
}

// MARK: - ViewController

final class SearchUpgradedViewController: ViewController {

    private enum SearchMode: Int, CaseIterable {
        case anime = 0
        case episodes = 1
        case tag = 2
        case advanced = 3

        var title: String {
            switch self {
            case .anime:
                return NSLocalizedString("动画", comment: "")
            case .episodes:
                return NSLocalizedString("剧集", comment: "")
            case .tag:
                return NSLocalizedString("标签", comment: "")
            case .advanced:
                return NSLocalizedString("高级", comment: "")
            }
        }

        var placeholder: String {
            switch self {
            case .anime, .episodes:
                return NSLocalizedString("动画名称", comment: "")
            case .tag:
                return NSLocalizedString("标签1,标签2", comment: "")
            case .advanced:
                return NSLocalizedString("关键词（可选）", comment: "")
            }
        }

        var hint: String {
            switch self {
            case .anime:
                return NSLocalizedString("输入动画名称，搜索弹弹play 作品库。", comment: "")
            case .episodes:
                return NSLocalizedString("输入动画名称，可选填写剧集关键词；结果可展开查看剧集。", comment: "")
            case .tag:
                return NSLocalizedString("多个标签用英文逗号分隔，最多 10 个；区分大小写。", comment: "")
            case .advanced:
                return NSLocalizedString("关键词可选；使用下方条件筛选，默认搜索弹弹play 数据库。", comment: "")
            }
        }
    }

    private var mode: SearchMode = .anime
    private var nodes: [SearchUpgradeResultNode] = []
    private var searchTask: Task<Void, Never>?
    private var configTask: Task<Void, Never>?
    private var loadedConfigSource: String?
    private var lastTableWidth: CGFloat = 0

    // MARK: - Controls

    private lazy var searchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = mode.placeholder
        field.target = self
        field.action = #selector(performSearch)
        field.setAccessibilityIdentifier(AccessibilityID.Search.searchField)
        field.setAccessibilityLabel(NSLocalizedString("搜索关键词", comment: ""))
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }()

    private lazy var modeControl: NSSegmentedControl = {
        let control = NSSegmentedControl(
            labels: SearchMode.allCases.map(\.title),
            trackingMode: .selectOne,
            target: self,
            action: #selector(modeChanged)
        )
        control.selectedSegment = SearchMode.anime.rawValue
        control.segmentStyle = .texturedRounded
        control.setAccessibilityIdentifier(AccessibilityID.Search.modeControl)
        control.setAccessibilityLabel(NSLocalizedString("搜索模式", comment: ""))
        for index in 0..<SearchMode.allCases.count {
            control.setWidth(64, forSegment: index)
        }
        return control
    }()

    private lazy var searchButton: Button = {
        let button = Button(title: NSLocalizedString("搜索", comment: ""), target: self, action: #selector(performSearch))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.setAccessibilityIdentifier(AccessibilityID.Search.searchButton)
        button.setAccessibilityLabel(NSLocalizedString("开始搜索", comment: ""))
        return button
    }()

    private lazy var episodeField: NSTextField = {
        let field = NSTextField()
        field.placeholderString = NSLocalizedString("剧集（可选，如 1 或 第1话）", comment: "")
        field.setAccessibilityIdentifier(AccessibilityID.Search.episodeField)
        field.setAccessibilityLabel(NSLocalizedString("剧集关键词", comment: ""))
        return field
    }()

    private lazy var episodeRow: NSStackView = {
        let label = Label(labelWithString: NSLocalizedString("剧集筛选", comment: ""))
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        let stack = NSStackView(views: [label, episodeField])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        episodeField.snp.makeConstraints { make in
            make.width.equalTo(260)
        }
        stack.isHidden = true
        return stack
    }()

    private lazy var hintLabel: Label = {
        let label = Label(labelWithString: mode.hint)
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.maximumNumberOfLines = 2
        label.setAccessibilityIdentifier(AccessibilityID.Search.hintLabel)
        return label
    }()

    private lazy var summaryLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.maximumNumberOfLines = 2
        label.setAccessibilityIdentifier(AccessibilityID.Search.summaryLabel)
        label.isHidden = true
        return label
    }()

    private lazy var typePopup = makePopup(placeholder: NSLocalizedString("全部", comment: ""), identifier: AccessibilityID.Search.typePopup)
    private lazy var yearPopup = makePopup(placeholder: NSLocalizedString("全部", comment: ""), identifier: AccessibilityID.Search.yearPopup)
    private lazy var monthPopup = makePopup(placeholder: NSLocalizedString("全部", comment: ""), identifier: AccessibilityID.Search.monthPopup)
    private lazy var minRatingPopup = makePopup(placeholder: "0", identifier: AccessibilityID.Search.minRatingPopup)
    private lazy var maxRatingPopup = makePopup(placeholder: "10", identifier: AccessibilityID.Search.maxRatingPopup)
    private lazy var sortPopup = makePopup(placeholder: NSLocalizedString("默认排序", comment: ""), identifier: AccessibilityID.Search.sortPopup)
    private lazy var sourcePopup = makePopup(placeholder: NSLocalizedString("弹弹play", comment: ""), identifier: AccessibilityID.Search.sourcePopup)

    private lazy var tagsField: NSTextField = {
        let field = NSTextField()
        field.placeholderString = NSLocalizedString("标签1,标签2（最多 10 个）", comment: "")
        field.setAccessibilityIdentifier(AccessibilityID.Search.tagsField)
        field.setAccessibilityLabel(NSLocalizedString("高级搜索标签", comment: ""))
        field.snp.makeConstraints { make in
            make.width.equalTo(230)
        }
        return field
    }()

    private lazy var restrictedPopup = makePopup(placeholder: NSLocalizedString("全部", comment: ""), identifier: AccessibilityID.Search.restrictedPopup)

    private lazy var advancedPanel: NSStackView = {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 8
        panel.setAccessibilityIdentifier(AccessibilityID.Search.advancedPanel)
        return panel
    }()

    private lazy var statusLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_normal()
        label.textColor = .subtitleTextColor
        label.alignment = .center
        label.maximumNumberOfLines = 4
        label.setAccessibilityIdentifier(AccessibilityID.Search.statusLabel)
        return label
    }()

    private lazy var loadingIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isDisplayedWhenStopped = false
        indicator.setAccessibilityIdentifier(AccessibilityID.Search.loadingIndicator)
        return indicator
    }()

    private lazy var statusStack: NSStackView = {
        let stack = NSStackView(views: [loadingIndicator, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        return stack
    }()

    private lazy var controlsStack: NSStackView = {
        let header = NSStackView(views: [searchField, modeControl, searchButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10

        let options = NSStackView(views: [episodeRow, hintLabel])
        options.orientation = .vertical
        options.alignment = .leading
        options.spacing = 6

        let stack = NSStackView(views: [header, options, advancedPanel, summaryLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.detachesHiddenViews = true

        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        options.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        hintLabel.widthAnchor.constraint(equalTo: options.widthAnchor).isActive = true
        advancedPanel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        summaryLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }()

    private lazy var outlineView: OutlineView = {
        let outlineView = OutlineView()
        outlineView.style = .plain
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.rowSizeStyle = .custom
        outlineView.rowHeight = 64
        outlineView.intercellSpacing = NSSize(width: 0, height: 0)
        outlineView.indentationPerLevel = 14
        outlineView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        outlineView.backgroundColor = .clear
        outlineView.setAccessibilityIdentifier(AccessibilityID.Search.resultsTable)
        outlineView.setAccessibilityLabel(NSLocalizedString("搜索结果", comment: ""))
        outlineView.registerClassCell(class: SearchUpgradeResultCellView.self)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("searchResult"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        return outlineView
    }()

    private lazy var scrollView: ScrollView<OutlineView> = {
        let scrollView = ScrollView(containerView: outlineView)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        return scrollView
    }()

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("搜索", comment: "")
        view.setAccessibilityIdentifier(AccessibilityID.Search.root)

        buildAdvancedPanel()
        populateAdvancedControls(with: .fallback())
        updateModeUI()

        view.addSubview(controlsStack)
        view.addSubview(scrollView)
        view.addSubview(statusStack)

        controlsStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(controlsStack.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
        statusStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-20)
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }

        showInitialState()
    }

    deinit {
        searchTask?.cancel()
        configTask?.cancel()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let width = scrollView.contentView.bounds.width
        guard width > 0 else { return }
        if abs(lastTableWidth - width) > 0.5 {
            lastTableWidth = width
            outlineView.tableColumns.first?.width = width
            outlineView.sizeLastColumnToFit()
            outlineView.reloadData()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(searchField)
    }

    // MARK: - UI construction

    private func makeLabel(_ text: String) -> Label {
        let label = Label(labelWithString: text)
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        return label
    }

    private func makePopup(placeholder: String, identifier: String) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.addItem(withTitle: placeholder)
        popup.setAccessibilityIdentifier(identifier)
        return popup
    }

    private func buildAdvancedPanel() {
        typePopup.setAccessibilityLabel(NSLocalizedString("类型", comment: ""))
        yearPopup.setAccessibilityLabel(NSLocalizedString("年份", comment: ""))
        monthPopup.setAccessibilityLabel(NSLocalizedString("月份", comment: ""))
        minRatingPopup.setAccessibilityLabel(NSLocalizedString("最低评分", comment: ""))
        maxRatingPopup.setAccessibilityLabel(NSLocalizedString("最高评分", comment: ""))
        sortPopup.setAccessibilityLabel(NSLocalizedString("排序", comment: ""))
        sourcePopup.setAccessibilityLabel(NSLocalizedString("数据库", comment: ""))

        sourcePopup.removeAllItems()
        sourcePopup.addItem(withTitle: NSLocalizedString("弹弹play", comment: ""))
        sourcePopup.item(at: 0)?.representedObject = SearchUpgradeRequest.defaultSource
        sourcePopup.addItem(withTitle: "TMDB")
        sourcePopup.item(at: 1)?.representedObject = "tmdb"
        sourcePopup.target = self
        sourcePopup.action = #selector(sourceChanged)

        restrictedPopup.removeAllItems()
        restrictedPopup.addItem(withTitle: NSLocalizedString("全部", comment: ""))
        restrictedPopup.item(at: 0)?.representedObject = -1
        restrictedPopup.addItem(withTitle: NSLocalizedString("不包含", comment: ""))
        restrictedPopup.item(at: 1)?.representedObject = 0
        restrictedPopup.addItem(withTitle: NSLocalizedString("仅限定内容", comment: ""))
        restrictedPopup.item(at: 2)?.representedObject = 1
        restrictedPopup.setAccessibilityLabel(NSLocalizedString("受限内容", comment: ""))

        let firstRow = NSStackView(views: [
            makeLabel(NSLocalizedString("类型", comment: "")), typePopup,
            makeLabel(NSLocalizedString("年份", comment: "")), yearPopup,
            makeLabel(NSLocalizedString("月份", comment: "")), monthPopup,
            makeLabel(NSLocalizedString("评分", comment: "")), minRatingPopup,
            makeLabel("-"), maxRatingPopup,
            makeLabel(NSLocalizedString("排序", comment: "")), sortPopup,
        ])
        firstRow.orientation = .horizontal
        firstRow.alignment = .centerY
        firstRow.spacing = 6

        let secondRow = NSStackView(views: [
            makeLabel(NSLocalizedString("标签", comment: "")), tagsField,
            makeLabel(NSLocalizedString("受限内容", comment: "")), restrictedPopup,
            makeLabel(NSLocalizedString("数据库", comment: "")), sourcePopup,
        ])
        secondRow.orientation = .horizontal
        secondRow.alignment = .centerY
        secondRow.spacing = 6

        typePopup.snp.makeConstraints { make in make.width.greaterThanOrEqualTo(90) }
        yearPopup.snp.makeConstraints { make in make.width.greaterThanOrEqualTo(80) }
        monthPopup.snp.makeConstraints { make in make.width.greaterThanOrEqualTo(70) }
        minRatingPopup.snp.makeConstraints { make in make.width.greaterThanOrEqualTo(58) }
        maxRatingPopup.snp.makeConstraints { make in make.width.greaterThanOrEqualTo(58) }
        sortPopup.snp.makeConstraints { make in make.width.greaterThanOrEqualTo(140) }

        advancedPanel.addArrangedSubview(firstRow)
        advancedPanel.addArrangedSubview(secondRow)
        firstRow.widthAnchor.constraint(equalTo: advancedPanel.widthAnchor).isActive = true
        secondRow.widthAnchor.constraint(equalTo: advancedPanel.widthAnchor).isActive = true
        advancedPanel.isHidden = true
    }

    private func updateModeUI() {
        searchField.placeholderString = mode.placeholder
        hintLabel.text = mode.hint
        episodeRow.isHidden = mode != .episodes
        advancedPanel.isHidden = mode != .advanced
        if mode == .advanced {
            loadAdvancedConfigIfNeeded()
        }
    }

    // MARK: - Actions

    @objc private func modeChanged() {
        mode = SearchMode(rawValue: modeControl.selectedSegment) ?? .anime
        updateModeUI()
        clearResults()
        showInitialState()
        searchField.becomeFirstResponder()
    }

    @objc private func sourceChanged() {
        loadedConfigSource = nil
        loadAdvancedConfigIfNeeded(force: true)
    }

    @objc private func performSearch() {
        startSearch()
    }

    private func startSearch() {
        searchTask?.cancel()

        let keyword = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentMode = mode

        if currentMode != .advanced && keyword.isEmpty {
            showErrorState(NSLocalizedString("请输入搜索关键词", comment: ""))
            return
        }

        if currentMode == .tag, SearchUpgradeRequest.normalizedTags(keyword).isEmpty {
            showErrorState(NSLocalizedString("请输入至少一个标签", comment: ""))
            return
        }

        if currentMode == .advanced {
            loadAdvancedConfigIfNeeded()
        }

        showLoadingState(NSLocalizedString("正在搜索…", comment: ""))
        ANX.logInfo(.HTTP, "[SearchUpgrade] 搜索 mode=\(currentMode) keyword=\(keyword)")

        searchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                self.showErrorState(NSLocalizedString("登录后才能搜索", comment: ""))
                return
            }

            do {
                switch currentMode {
                case .anime:
                    let response = try await SearchUpgradeNetworkHandle.searchAnime(keyword: keyword)
                    try Task.checkCancellation()
                    self.applyAnime(response.animes)

                case .episodes:
                    let response = try await SearchUpgradeNetworkHandle.searchEpisodes(
                        anime: keyword,
                        episode: self.episodeField.stringValue
                    )
                    try Task.checkCancellation()
                    self.applyEpisodes(response.animes, hasMore: response.hasMore)

                case .tag:
                    let response = try await SearchUpgradeNetworkHandle.searchByTags(rawTags: keyword)
                    try Task.checkCancellation()
                    self.applyBangumis(response.bangumis, hasMore: false)

                case .advanced:
                    let query = try SearchUpgradeAdvancedQuery(
                        source: self.currentSource,
                        keyword: keyword,
                        type: self.selectedIntValue(self.typePopup).flatMap { $0 >= 0 ? $0 : nil },
                        tags: SearchUpgradeRequest.normalizedTags(self.tagsField.stringValue),
                        year: self.selectedIntValue(self.yearPopup).flatMap { $0 >= 0 ? $0 : nil },
                        month: self.selectedIntValue(self.monthPopup).flatMap { $0 >= 0 ? $0 : nil },
                        minRate: self.selectedIntValue(self.minRatingPopup),
                        maxRate: self.selectedIntValue(self.maxRatingPopup),
                        restricted: self.selectedRestrictedValue,
                        sort: self.selectedIntValue(self.sortPopup).flatMap(SearchUpgradeSort.init(rawValue:))
                    )
                    let response = try await SearchUpgradeNetworkHandle.advancedSearch(query)
                    try Task.checkCancellation()
                    self.applyBangumis(response.bangumis, hasMore: false)
                }
            } catch is CancellationError {
                // 用户发起了更新的搜索，忽略旧结果。
            } catch let error as APIError {
                if case .cancelled = error { return }
                self.showErrorState(error.localizedDescription)
            } catch {
                self.showErrorState(error.localizedDescription)
            }
        }
    }

    // MARK: - Results

    private func clearResults() {
        nodes = []
        outlineView.reloadData()
        summaryLabel.isHidden = true
    }

    private func applyAnime(_ animes: [SearchUpgradeAnimeItem]) {
        let nodes = animes.map { anime -> SearchUpgradeResultNode in
            var parts: [String] = []
            if !anime.typeDescription.isEmpty { parts.append(anime.typeDescription) }
            if anime.episodeCount > 0 {
                parts.append(String(format: NSLocalizedString("%d 集", comment: ""), anime.episodeCount))
            }
            if let date = anime.startDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                parts.append(formatter.string(from: date))
            }
            return SearchUpgradeResultNode(
                animeId: anime.animeId,
                title: anime.animeTitle,
                detail: parts.joined(separator: " · "),
                rating: anime.rating,
                imageUrl: anime.imageUrl
            )
        }
        apply(nodes: nodes, summary: resultSummary(count: nodes.count, hasMore: false))
    }

    private func applyEpisodes(_ animes: [SearchUpgradeEpisodeAnime], hasMore: Bool) {
        let nodes = animes.map { anime -> SearchUpgradeResultNode in
            let children = anime.episodes.map { episode in
                SearchUpgradeResultNode(
                    animeId: anime.animeId,
                    title: episode.episodeTitle,
                    detail: NSLocalizedString("剧集 · 点击查看作品详情", comment: ""),
                    isEpisode: true
                )
            }
            var parts: [String] = []
            if !anime.typeDescription.isEmpty { parts.append(anime.typeDescription) }
            if !children.isEmpty {
                parts.append(String(format: NSLocalizedString("%d 个剧集结果", comment: ""), children.count))
            }
            return SearchUpgradeResultNode(
                animeId: anime.animeId,
                title: anime.animeTitle,
                detail: parts.joined(separator: " · "),
                imageUrl: anime.imageUrl,
                children: children
            )
        }
        apply(nodes: nodes, summary: resultSummary(count: nodes.count, hasMore: hasMore))

        // 剧集结果默认展开，直接展示剧集列表。
        for node in nodes where !node.children.isEmpty {
            outlineView.expandItem(node)
        }
    }

    private func applyBangumis(_ bangumis: [SearchUpgradeBangumiItem], hasMore: Bool) {
        let nodes = bangumis.map { bangumi -> SearchUpgradeResultNode in
            var parts: [String] = []
            if bangumi.rank > 0 {
                parts.append("#\(bangumi.rank)")
            }
            if !bangumi.typeDescription.isEmpty { parts.append(bangumi.typeDescription) }
            if bangumi.isOnAir {
                parts.append(NSLocalizedString("连载中", comment: ""))
            }
            if !bangumi.intro.isEmpty {
                parts.append(bangumi.intro)
            }
            return SearchUpgradeResultNode(
                animeId: bangumi.animeId,
                title: bangumi.animeTitle,
                detail: parts.joined(separator: " · "),
                rating: bangumi.rating,
                imageUrl: bangumi.imageUrl
            )
        }
        apply(nodes: nodes, summary: resultSummary(count: nodes.count, hasMore: hasMore))
    }

    private func apply(nodes: [SearchUpgradeResultNode], summary: String) {
        self.nodes = nodes
        outlineView.reloadData()
        scrollView.isHidden = nodes.isEmpty
        statusStack.isHidden = !nodes.isEmpty
        statusLabel.stringValue = nodes.isEmpty ? NSLocalizedString("没有找到结果", comment: "") : ""
        summaryLabel.stringValue = summary
        summaryLabel.isHidden = nodes.isEmpty
        loadingIndicator.stopAnimation(nil)
    }

    private func resultSummary(count: Int, hasMore: Bool) -> String {
        let base = String(format: NSLocalizedString("共 %d 个结果", comment: ""), count)
        if hasMore {
            return base + " · " + NSLocalizedString("结果较多，仅显示部分，请填写更精确的条件", comment: "")
        }
        return base
    }

    // MARK: - Status

    private func showInitialState() {
        clearResults()
        loadingIndicator.stopAnimation(nil)
        scrollView.isHidden = true
        statusStack.isHidden = false
        statusLabel.stringValue = mode == .advanced
            ? NSLocalizedString("设置筛选条件后点击搜索", comment: "")
            : NSLocalizedString("输入关键词后点击搜索", comment: "")
        summaryLabel.isHidden = true
    }

    private func showLoadingState(_ text: String) {
        loadingIndicator.startAnimation(nil)
        scrollView.isHidden = true
        statusStack.isHidden = false
        statusLabel.stringValue = text
        summaryLabel.isHidden = true
    }

    private func showErrorState(_ text: String) {
        loadingIndicator.stopAnimation(nil)
        nodes = []
        outlineView.reloadData()
        scrollView.isHidden = true
        statusStack.isHidden = false
        statusLabel.stringValue = text
        summaryLabel.isHidden = true
        ANX.logError(.HTTP, "[SearchUpgrade] 搜索失败: \(text)")
    }

    // MARK: - Advanced config

    private var currentSource: String {
        (sourcePopup.selectedItem?.representedObject as? String) ?? SearchUpgradeRequest.defaultSource
    }

    private var selectedRestrictedValue: Bool? {
        switch selectedIntValue(restrictedPopup) ?? -1 {
        case 0:
            return false
        case 1:
            return true
        default:
            return nil
        }
    }

    private func selectedIntValue(_ popup: NSPopUpButton) -> Int? {
        popup.selectedItem?.representedObject as? Int
    }

    private func loadAdvancedConfigIfNeeded(force: Bool = false) {
        let source = currentSource
        guard force || loadedConfigSource != source else { return }

        configTask?.cancel()
        populateAdvancedControls(with: .fallback())

        configTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let config = try await SearchUpgradeNetworkHandle.advancedConfig(source: source)
                guard !Task.isCancelled else { return }
                self.loadedConfigSource = source
                self.populateAdvancedControls(with: config)
                ANX.logInfo(.HTTP, "[SearchUpgrade] 高级配置加载成功 source=\(source)")
            } catch {
                guard !Task.isCancelled else { return }
                // 配置接口失败时保留内置默认，不阻断搜索。
                self.loadedConfigSource = source
                self.populateAdvancedControls(with: .fallback())
                ANX.logError(.HTTP, "[SearchUpgrade] 高级配置加载失败，使用内置默认: \(error)")
            }
        }
    }

    private func populateAdvancedControls(with config: SearchUpgradeAdvancedConfigResponse) {
        let oldType = selectedIntValue(typePopup)
        let oldYear = selectedIntValue(yearPopup)
        let oldMonth = selectedIntValue(monthPopup)
        let oldMinRate = selectedIntValue(minRatingPopup) ?? 0
        let oldMaxRate = selectedIntValue(maxRatingPopup) ?? 10
        let oldSort = selectedIntValue(sortPopup) ?? SearchUpgradeSort.defaultSort.rawValue

        rebuildPopup(typePopup, allTitle: NSLocalizedString("全部", comment: ""), allValue: -1,
                     entries: config.types.map { ($0.value, $0.key) }, selected: oldType)
        rebuildPopup(monthPopup, allTitle: NSLocalizedString("全部", comment: ""), allValue: -1,
                     entries: (1...12).map { ("\($0)月", $0) }, selected: oldMonth)

        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        let lower = max(1900, min(min(config.minYear, config.maxYear), currentYear))
        let upper = min(currentYear + 1, max(max(config.minYear, config.maxYear), lower))
        let years = stride(from: upper, through: lower, by: -1).map { ("\($0)年", $0) }
        rebuildPopup(yearPopup, allTitle: NSLocalizedString("全部", comment: ""), allValue: -1,
                     entries: years, selected: oldYear)

        rebuildPopup(minRatingPopup, allTitle: nil, allValue: nil,
                     entries: (0...10).map { ("\($0)", $0) }, selected: oldMinRate)
        rebuildPopup(maxRatingPopup, allTitle: nil, allValue: nil,
                     entries: (0...10).map { ("\($0)", $0) }, selected: oldMaxRate)

        var sorts: [(String, Int)] = config.sorts.compactMap { entry in
            guard let sort = SearchUpgradeSort(rawValue: entry.key) else { return nil }
            return (entry.value.isEmpty ? sort.title : entry.value, sort.rawValue)
        }
        if sorts.isEmpty {
            sorts = SearchUpgradeSort.allCases.map { ($0.title, $0.rawValue) }
        }
        rebuildPopup(sortPopup, allTitle: nil, allValue: nil, entries: sorts, selected: oldSort)
    }

    private func rebuildPopup(
        _ popup: NSPopUpButton,
        allTitle: String?,
        allValue: Int?,
        entries: [(String, Int)],
        selected: Int?
    ) {
        popup.removeAllItems()
        if let allTitle = allTitle, let allValue = allValue {
            popup.addItem(withTitle: allTitle)
            popup.lastItem?.representedObject = allValue
        }
        for (title, value) in entries {
            popup.addItem(withTitle: title)
            popup.lastItem?.representedObject = value
        }
        guard popup.numberOfItems > 0 else { return }

        let target = selected ?? allValue ?? entries.first?.1
        if let target = target,
           let index = popup.itemArray.firstIndex(where: { ($0.representedObject as? Int) == target }) {
            popup.selectItem(at: index)
        } else {
            popup.selectItem(at: 0)
        }
    }
}

// MARK: - NSOutlineViewDataSource

extension SearchUpgradedViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? SearchUpgradeResultNode {
            return node.children.count
        }
        return nodes.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? SearchUpgradeResultNode {
            return node.children[index]
        }
        return nodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? SearchUpgradeResultNode)?.children.isEmpty == false
    }
}

// MARK: - NSOutlineViewDelegate

extension SearchUpgradedViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SearchUpgradeResultNode else { return nil }
        let cell = outlineView.dequeueReusableCell(class: SearchUpgradeResultCellView.self)
        cell.update(node: node)
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        outlineView.themedRowView(forRow: outlineView.row(forItem: item))
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let row = outlineView.selectedRow
        guard row >= 0 else { return }
        outlineView.deselectRow(row)
        guard let node = outlineView.item(atRow: row) as? SearchUpgradeResultNode else { return }

        if !node.children.isEmpty {
            if outlineView.isItemExpanded(node) {
                outlineView.collapseItem(node)
            } else {
                outlineView.expandItem(node)
            }
            return
        }

        guard node.animeId > 0 else { return }
        ANX.logInfo(.UI, "[SearchUpgrade] 打开作品详情 animeId=\(node.animeId)")
        navigator?.pushViewController(BangumiDetailViewController(animateId: node.animeId))
    }
}
