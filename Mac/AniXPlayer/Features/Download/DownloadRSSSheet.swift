//
//  DownloadRSSSheet.swift
//  AniXPlayer
//
//  macOS：RSS 订阅管理 sheet（feed 列表、刷新、关键词、自动下载与条目下载）。
//

import Cocoa
import SnapKit

final class DownloadRSSSheetViewController: ViewController {

    private let manager: DownloadManager
    private let store: RSSFeedStore
    private let service: RSSFeedService

    private var feeds: [RSSFeedSubscription]
    private var selectedFeedID: UUID?
    private var itemsByFeed: [UUID: [RSSFeedItem]] = [:]
    private var selectedItemIDs: Set<String> = []
    private var isLoading = false

    private let feedTable = NSTableView()
    private let feedScroll = NSScrollView()
    private let itemsTable = NSTableView()
    private let itemsScroll = NSScrollView()
    private let feedTitleLabel = DownloadRSSSheetViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 13, weight: .semibold),
        color: .labelColor
    )
    private let feedURLLabel = DownloadRSSSheetViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 10.5),
        color: .secondaryLabelColor
    )
    private let statusLabel = DownloadRSSSheetViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor
    )
    private let autoCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let keywordField = NSTextField()
    private let applyKeywordsButton = NSButton(title: "", target: nil, action: nil)
    private let addFeedButton = NSButton(title: "", target: nil, action: nil)
    private let removeFeedButton = NSButton(title: "", target: nil, action: nil)
    private let refreshButton = NSButton(title: "", target: nil, action: nil)
    private let downloadSelectedButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let spinner = NSProgressIndicator()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    init(
        manager: DownloadManager,
        store: RSSFeedStore = .shared,
        service: RSSFeedService = .shared
    ) {
        self.manager = manager
        self.store = store
        self.service = service
        self.feeds = store.feeds()
        self.selectedFeedID = feeds.first?.id
        super.init()
        preferredContentSize = NSSize(width: 900, height: 600)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.Download.rssSheet)
        setupLayout()
        setupTables()
        reloadFeedTable()
        updateSelectedFeed()
    }

    // MARK: Layout

    private func setupLayout() {
        let title = Self.makeLabel(
            NSLocalizedString("RSS 订阅", comment: ""),
            font: .systemFont(ofSize: 17, weight: .semibold),
            color: .labelColor
        )
        let hint = Self.makeLabel(
            NSLocalizedString(
                "支持 RSS 2.0 / Atom。只有勾选“自动下载新条目”的订阅会在刷新时自动添加匹配的新条目（单次最多 20 条）。",
                comment: ""
            ),
            font: .systemFont(ofSize: 11),
            color: .secondaryLabelColor
        )
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 2

        autoCheckbox.title = NSLocalizedString("自动下载新条目", comment: "")
        autoCheckbox.target = self
        autoCheckbox.action = #selector(autoDownloadToggled)
        autoCheckbox.setAccessibilityIdentifier(AccessibilityID.Download.rssAutoDownload)

        keywordField.placeholderString = NSLocalizedString(
            "关键词过滤，例如：1080p, 简中（留空表示全部）",
            comment: ""
        )
        keywordField.delegate = self
        keywordField.setAccessibilityIdentifier(AccessibilityID.Download.rssKeywords)

        applyKeywordsButton.title = NSLocalizedString("应用筛选", comment: "")
        applyKeywordsButton.bezelStyle = .rounded
        applyKeywordsButton.controlSize = .small
        applyKeywordsButton.target = self
        applyKeywordsButton.action = #selector(applyKeywordsTapped)
        applyKeywordsButton.setAccessibilityIdentifier(AccessibilityID.Download.rssApplyKeywords)

        addFeedButton.title = NSLocalizedString("添加订阅…", comment: "")
        addFeedButton.bezelStyle = .rounded
        addFeedButton.target = self
        addFeedButton.action = #selector(addFeedTapped)
        addFeedButton.setAccessibilityIdentifier(AccessibilityID.Download.rssAddFeed)

        removeFeedButton.title = NSLocalizedString("删除订阅", comment: "")
        removeFeedButton.bezelStyle = .rounded
        removeFeedButton.target = self
        removeFeedButton.action = #selector(removeFeedTapped)
        removeFeedButton.setAccessibilityIdentifier(AccessibilityID.Download.rssRemoveFeed)

        refreshButton.title = NSLocalizedString("刷新", comment: "")
        refreshButton.bezelStyle = .rounded
        refreshButton.controlSize = .small
        refreshButton.target = self
        refreshButton.action = #selector(refreshTapped)
        refreshButton.setAccessibilityIdentifier(AccessibilityID.Download.rssRefresh)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.setAccessibilityIdentifier(AccessibilityID.Download.rssSpinner)

        downloadSelectedButton.title = NSLocalizedString("下载所选", comment: "")
        downloadSelectedButton.bezelStyle = .rounded
        downloadSelectedButton.target = self
        downloadSelectedButton.action = #selector(downloadSelectedTapped)
        downloadSelectedButton.setAccessibilityIdentifier(
            AccessibilityID.Download.rssDownloadSelected
        )

        closeButton.title = NSLocalizedString("完成", comment: "")
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.setAccessibilityIdentifier(AccessibilityID.Download.rssClose)

        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.setAccessibilityIdentifier(AccessibilityID.Download.rssStatus)

        feedURLLabel.lineBreakMode = .byTruncatingMiddle

        let views: [NSView] = [
            title, hint, feedScroll, addFeedButton, removeFeedButton,
            feedTitleLabel, feedURLLabel, autoCheckbox, refreshButton, spinner,
            keywordField, applyKeywordsButton, itemsScroll,
            statusLabel, downloadSelectedButton, closeButton,
        ]
        views.forEach(view.addSubview)

        title.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalToSuperview().offset(20)
        }
        hint.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(title.snp.bottom).offset(6)
        }

        feedScroll.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(hint.snp.bottom).offset(12)
            make.width.equalTo(270)
            make.bottom.equalTo(addFeedButton.snp.top).offset(-8)
        }
        addFeedButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.bottom.equalToSuperview().offset(-18)
        }
        removeFeedButton.snp.makeConstraints { make in
            make.leading.equalTo(addFeedButton.snp.trailing).offset(8)
            make.centerY.equalTo(addFeedButton)
        }

        feedTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(feedScroll.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(feedScroll)
        }
        feedURLLabel.snp.makeConstraints { make in
            make.leading.equalTo(feedTitleLabel)
            make.trailing.equalTo(feedTitleLabel)
            make.top.equalTo(feedTitleLabel.snp.bottom).offset(2)
        }
        autoCheckbox.snp.makeConstraints { make in
            make.leading.equalTo(feedTitleLabel)
            make.top.equalTo(feedURLLabel.snp.bottom).offset(10)
        }
        refreshButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(autoCheckbox)
        }
        spinner.snp.makeConstraints { make in
            make.trailing.equalTo(refreshButton.snp.leading).offset(-8)
            make.centerY.equalTo(refreshButton)
            make.width.height.equalTo(16)
        }
        keywordField.snp.makeConstraints { make in
            make.leading.equalTo(feedTitleLabel)
            make.top.equalTo(autoCheckbox.snp.bottom).offset(8)
            make.trailing.equalTo(applyKeywordsButton.snp.leading).offset(-8)
            make.height.equalTo(24)
        }
        applyKeywordsButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(keywordField)
        }
        keywordField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        itemsScroll.snp.makeConstraints { make in
            make.leading.equalTo(feedScroll.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(keywordField.snp.bottom).offset(10)
            make.bottom.equalTo(statusLabel.snp.top).offset(-8)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(itemsScroll)
            make.bottom.equalToSuperview().offset(-20)
            make.trailing.lessThanOrEqualTo(downloadSelectedButton.snp.leading).offset(-12)
        }
        downloadSelectedButton.snp.makeConstraints { make in
            make.trailing.equalTo(closeButton.snp.leading).offset(-8)
            make.centerY.equalTo(closeButton)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.bottom.equalToSuperview().offset(-18)
            make.width.greaterThanOrEqualTo(80)
        }

        feedScroll.hasVerticalScroller = true
        feedScroll.autohidesScrollers = true
        feedScroll.drawsBackground = false
        feedScroll.borderType = .noBorder
        feedScroll.documentView = feedTable

        itemsScroll.hasVerticalScroller = true
        itemsScroll.autohidesScrollers = true
        itemsScroll.drawsBackground = false
        itemsScroll.borderType = .noBorder
        itemsScroll.documentView = itemsTable
    }

    private func setupTables() {
        let feedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("feed"))
        feedColumn.title = NSLocalizedString("订阅", comment: "")
        feedColumn.width = 260
        feedColumn.minWidth = 180
        feedColumn.resizingMask = [.autoresizingMask]
        feedTable.addTableColumn(feedColumn)
        feedTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        feedTable.headerView = nil
        feedTable.rowHeight = 46
        feedTable.dataSource = self
        feedTable.delegate = self
        feedTable.setAccessibilityIdentifier(AccessibilityID.Download.rssFeedTable)

        let columns: [(String, String, CGFloat)] = [
            ("title", NSLocalizedString("标题", comment: ""), 330),
            ("date", NSLocalizedString("日期", comment: ""), 130),
            ("size", NSLocalizedString("大小", comment: ""), 90),
        ]
        for (identifier, title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.minWidth = 60
            if identifier == "title" {
                column.resizingMask = [.autoresizingMask]
            }
            itemsTable.addTableColumn(column)
        }
        itemsTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        itemsTable.rowHeight = 30
        itemsTable.allowsMultipleSelection = true
        itemsTable.dataSource = self
        itemsTable.delegate = self
        itemsTable.target = self
        itemsTable.doubleAction = #selector(itemDoubleClicked)
        itemsTable.setAccessibilityIdentifier(AccessibilityID.Download.rssItems)
    }

    // MARK: Data

    private var selectedFeedIndex: Int? {
        guard let selectedFeedID else { return nil }
        return feeds.firstIndex { $0.id == selectedFeedID }
    }

    private var currentItems: [RSSFeedItem] {
        guard let selectedFeedID else { return [] }
        return itemsByFeed[selectedFeedID] ?? []
    }

    private func reloadFeedTable() {
        feedTable.reloadData()
        if let selectedFeedID,
           let index = feeds.firstIndex(where: { $0.id == selectedFeedID }) {
            feedTable.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else if !feeds.isEmpty {
            selectedFeedID = feeds[0].id
            feedTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        } else {
            selectedFeedID = nil
        }
    }

    private func reloadItems() {
        itemsTable.reloadData()
        selectedItemIDs.removeAll()
        updateButtons()
    }

    private func updateSelectedFeed() {
        guard let index = selectedFeedIndex else {
            feedTitleLabel.stringValue = NSLocalizedString("未选择订阅", comment: "")
            feedURLLabel.stringValue = ""
            keywordField.stringValue = ""
            autoCheckbox.state = .off
            autoCheckbox.isEnabled = false
            keywordField.isEnabled = false
            applyKeywordsButton.isEnabled = false
            removeFeedButton.isEnabled = false
            refreshButton.isEnabled = false
            downloadSelectedButton.isEnabled = false
            if feeds.isEmpty {
                setStatus(
                    NSLocalizedString("还没有 RSS 订阅。点击“添加订阅…”输入 RSS 或 Atom 地址。", comment: ""),
                    color: .secondaryLabelColor
                )
            }
            reloadItems()
            return
        }

        let feed = feeds[index]
        feedTitleLabel.stringValue = feed.displayTitle
        feedTitleLabel.toolTip = feed.url
        feedURLLabel.stringValue = feed.url
        feedURLLabel.toolTip = feed.url
        keywordField.stringValue = feed.keywordFilters.joined(separator: ", ")
        autoCheckbox.state = feed.isAutoDownloadEnabled ? .on : .off
        autoCheckbox.isEnabled = true
        keywordField.isEnabled = true
        applyKeywordsButton.isEnabled = true
        removeFeedButton.isEnabled = true
        refreshButton.isEnabled = !isLoading
        itemsTable.reloadData()
        selectedItemIDs.removeAll()

        if currentItems.isEmpty {
            setStatus(
                NSLocalizedString("点击“刷新”获取订阅条目。", comment: ""),
                color: .secondaryLabelColor
            )
        }
        updateButtons()
    }

    private func updateButtons() {
        let hasFeed = selectedFeedIndex != nil
        addFeedButton.isEnabled = !isLoading
        downloadSelectedButton.isEnabled = !selectedItemIDs.isEmpty && !isLoading
        refreshButton.isEnabled = hasFeed && !isLoading
        if let feed = selectedFeedIndex.map({ feeds[$0] }) {
            autoCheckbox.isEnabled = true
            autoCheckbox.state = feed.isAutoDownloadEnabled ? .on : .off
        }
        removeFeedButton.isEnabled = hasFeed && !isLoading
        if isLoading {
            refreshButton.isEnabled = false
            downloadSelectedButton.isEnabled = false
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
    }

    private func setStatus(_ text: String, color: NSColor) {
        statusLabel.textColor = color
        statusLabel.stringValue = text
        statusLabel.toolTip = text
    }

    private func setLoading(_ loading: Bool) {
        isLoading = loading
        updateButtons()
    }

    // MARK: Actions

    @objc private func addFeedTapped() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("添加 RSS 订阅", comment: "")
        alert.informativeText = NSLocalizedString(
            "输入 RSS 2.0 或 Atom 地址。自动下载默认关闭，需要手动勾选。",
            comment: ""
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("添加", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        let titleField = NSTextField()
        titleField.placeholderString = NSLocalizedString("名称（可选）", comment: "")
        titleField.setAccessibilityIdentifier(AccessibilityID.Download.rssFeedAddTitle)
        let urlField = NSTextField()
        urlField.placeholderString = "https://example.com/feed.xml"
        urlField.setAccessibilityIdentifier(AccessibilityID.Download.rssFeedAddURL)
        let keywordsField = NSTextField()
        keywordsField.placeholderString = NSLocalizedString("关键词过滤（可选）", comment: "")
        keywordsField.setAccessibilityIdentifier(AccessibilityID.Download.rssFeedAddKeywords)
        let auto = NSButton(checkboxWithTitle: NSLocalizedString("自动下载新条目", comment: ""), target: nil, action: nil)
        auto.setAccessibilityIdentifier(AccessibilityID.Download.rssFeedAddAuto)

        let grid = NSGridView(views: [
            [Self.formLabel(NSLocalizedString("名称", comment: "")), titleField],
            [Self.formLabel("URL"), urlField],
            [Self.formLabel(NSLocalizedString("关键词", comment: "")), keywordsField],
            [NSView(), auto],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.frame = NSRect(x: 0, y: 0, width: 440, height: 120)
        grid.column(at: 0).xPlacement = .trailing
        alert.accessoryView = grid

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            let rawURL = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: rawURL),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  let host = url.host,
                  !host.isEmpty else {
                self.setStatus(
                    RSSFeedError.invalidURL(rawURL).localizedDescription,
                    color: .systemRed
                )
                return
            }

            let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let feed = RSSFeedSubscription(
                title: title.isEmpty ? host : title,
                url: rawURL,
                isAutoDownloadEnabled: auto.state == .on,
                keywordFilters: RSSKeywordFilter.parse(keywordsField.stringValue)
            )
            self.feeds.append(feed)
            self.selectedFeedID = feed.id
            self.store.save(self.feeds)
            self.reloadFeedTable()
            self.updateSelectedFeed()
            self.refreshSelectedFeed()
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    @objc private func removeFeedTapped() {
        guard let index = selectedFeedIndex else { return }
        let feed = feeds[index]

        let alert = NSAlert()
        alert.messageText = String(
            format: NSLocalizedString("删除订阅「%@」？", comment: ""),
            feed.displayTitle
        )
        alert.informativeText = NSLocalizedString("只会删除订阅，不会删除已经添加的下载任务或文件。", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("删除", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            self.feeds.remove(at: index)
            self.itemsByFeed.removeValue(forKey: feed.id)
            self.selectedFeedID = self.feeds.first?.id
            self.store.save(self.feeds)
            self.reloadFeedTable()
            self.updateSelectedFeed()
            self.setStatus(
                String(format: NSLocalizedString("已删除订阅「%@」。", comment: ""), feed.displayTitle),
                color: .secondaryLabelColor
            )
        }
        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    @objc private func refreshTapped() {
        refreshSelectedFeed()
    }

    private func refreshSelectedFeed() {
        guard let index = selectedFeedIndex, !isLoading else { return }
        let feed = feeds[index]
        setLoading(true)
        setStatus(
            String(format: NSLocalizedString("正在刷新「%@」…", comment: ""), feed.displayTitle),
            color: .secondaryLabelColor
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.service.fetch(feed: feed)
                DispatchQueue.main.async {
                    self.apply(result: result, feedID: feed.id)
                }
            } catch {
                DispatchQueue.main.async {
                    self.setLoading(false)
                    self.setStatus(error.localizedDescription, color: .systemRed)
                }
            }
        }
    }

    private func apply(result: RSSFeedParseResult, feedID: UUID) {
        guard let index = feeds.firstIndex(where: { $0.id == feedID }) else {
            setLoading(false)
            setStatus(
                NSLocalizedString("订阅已被删除，已忽略本次刷新结果。", comment: ""),
                color: .secondaryLabelColor
            )
            return
        }
        let previous = feeds[index]
        let candidates = RSSAutoDownload.itemsToAutoDownload(
            items: result.items,
            subscription: previous
        )

        itemsByFeed[feedID] = result.items
        feeds[index].seenItemIDs = RSSAutoDownload.updatedSeenItemIDs(
            existing: previous.seenItemIDs,
            items: result.items
        )
        if feeds[index].title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let feedTitle = result.title {
            feeds[index].title = feedTitle
        }
        store.save(feeds)
        setLoading(false)

        if selectedFeedID == feedID {
            reloadItems()
            updateSelectedFeed()
        }

        let baseMessage = result.items.isEmpty
            ? NSLocalizedString("订阅没有条目。", comment: "")
            : String(
                format: NSLocalizedString("已刷新：%d 个条目。", comment: ""),
                result.items.count
            )
        if !candidates.isEmpty {
            setStatus(
                baseMessage + String(
                    format: NSLocalizedString("正在自动添加 %d 个匹配的新条目…", comment: ""),
                    candidates.count
                ),
                color: .controlAccentColor
            )
            download(items: candidates, automatic: true)
        } else {
            setStatus(baseMessage, color: .secondaryLabelColor)
        }
    }

    @objc private func autoDownloadToggled() {
        guard let index = selectedFeedIndex else { return }
        feeds[index].isAutoDownloadEnabled = autoCheckbox.state == .on
        store.save(feeds)
        updateButtons()
        if autoCheckbox.state == .on {
            setStatus(
                NSLocalizedString("已开启自动下载；下次刷新时会自动添加关键词匹配的新条目。", comment: ""),
                color: .secondaryLabelColor
            )
        } else {
            setStatus(
                NSLocalizedString("已关闭自动下载，刷新不会自动添加任务。", comment: ""),
                color: .secondaryLabelColor
            )
        }
    }

    @objc private func applyKeywordsTapped() {
        guard let index = selectedFeedIndex else { return }
        feeds[index].keywordFilters = RSSKeywordFilter.parse(keywordField.stringValue)
        store.save(feeds)
        keywordField.stringValue = feeds[index].keywordFilters.joined(separator: ", ")
        let hint = feeds[index].keywordFilters.isEmpty
            ? NSLocalizedString("关键词过滤已清空（匹配全部条目）。", comment: "")
            : String(
                format: NSLocalizedString("关键词过滤已保存：%@", comment: ""),
                feeds[index].keywordFilters.joined(separator: ", ")
            )
        setStatus(hint, color: .secondaryLabelColor)
    }

    @objc private func downloadSelectedTapped() {
        let selected = itemsTable.selectedRowIndexes.compactMap { index -> RSSFeedItem? in
            let items = currentItems
            guard index >= 0, index < items.count else { return nil }
            return items[index]
        }
        guard !selected.isEmpty else { return }
        download(items: selected, automatic: false)
    }

    @objc private func itemDoubleClicked() {
        let row = itemsTable.clickedRow
        let items = currentItems
        guard row >= 0, row < items.count else { return }
        download(items: [items[row]], automatic: false)
    }

    private func download(items: [RSSFeedItem], automatic: Bool) {
        let directory = (try? manager.preferences.ensureDefaultSaveDirectory())
            ?? manager.preferences.defaultSaveDirectoryURL
        let bookmark = manager.preferences.defaultSaveBookmark
        let downloadable = items.compactMap { item -> (RSSFeedItem, String)? in
            let url = automatic ? item.autoDownloadURL : item.manualDownloadURL
            guard let url else { return nil }
            return (item, url)
        }
        guard !downloadable.isEmpty else {
            setStatus(
                NSLocalizedString("所选条目没有可下载的链接（缺少 enclosure）。", comment: ""),
                color: .systemOrange
            )
            return
        }

        setStatus(
            automatic
                ? String(
                    format: NSLocalizedString("正在自动添加 %d 个条目…", comment: ""),
                    downloadable.count
                )
                : String(
                    format: NSLocalizedString("正在添加 %d 个下载…", comment: ""),
                    downloadable.count
                ),
            color: .secondaryLabelColor
        )

        var succeeded = 0
        var duplicates = 0
        var failures = 0
        var firstError: String?

        for (item, url) in downloadable {
            manager.add(
                rawSource: url,
                savePath: directory.path,
                bookmark: bookmark
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let addResult):
                        if addResult.isDuplicate {
                            duplicates += 1
                        } else {
                            succeeded += 1
                        }
                    case .failure(let error):
                        failures += 1
                        if firstError == nil {
                            firstError = "\(item.displayTitle)：\(error.localizedDescription)"
                        }
                    }

                    let finished = succeeded + duplicates + failures
                    guard finished == downloadable.count else { return }

                    var parts: [String] = []
                    if succeeded > 0 {
                        parts.append(String(
                            format: NSLocalizedString("已添加 %d 个下载", comment: ""),
                            succeeded
                        ))
                    }
                    if duplicates > 0 {
                        parts.append(String(
                            format: NSLocalizedString("%d 个已存在", comment: ""),
                            duplicates
                        ))
                    }
                    if failures > 0 {
                        parts.append(String(
                            format: NSLocalizedString("%d 个失败", comment: ""),
                            failures
                        ))
                    }
                    let message = parts.joined(separator: "，") + "。"
                    if let firstError {
                        self.setStatus(
                            message + " " + firstError,
                            color: .systemRed
                        )
                    } else {
                        self.setStatus(message, color: .secondaryLabelColor)
                    }
                }
            }
        }
    }

    @objc private func closeTapped() {
        dismiss(self)
    }

    // MARK: Helpers

    private static func makeLabel(
        _ text: String,
        font: NSFont,
        color: NSColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private static func formLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        return label
    }
}

// MARK: - Tables

extension DownloadRSSSheetViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === feedTable ? feeds.count : currentItems.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        if tableView === feedTable {
            guard row < feeds.count else { return nil }
            let identifier = NSUserInterfaceItemIdentifier("download.rss.feed.cell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? RSSFeedCellView
                ?? RSSFeedCellView()
            cell.identifier = identifier
            cell.configure(feed: feeds[row])
            cell.setAccessibilityIdentifier("download.rss.feed." + feeds[row].id.uuidString)
            return cell
        }

        guard row < currentItems.count, let tableColumn else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("download.rss.item.\(tableColumn.identifier.rawValue)")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? Self.makeTextCell(identifier: identifier)
        let item = currentItems[row]
        switch tableColumn.identifier.rawValue {
        case "date":
            cell.textField?.stringValue = item.publishedAt.map { dateFormatter.string(from: $0) } ?? "—"
        case "size":
            cell.textField?.stringValue = (item.sizeBytes ?? 0) > 0
                ? DownloadFormatting.byteCount(item.sizeBytes ?? 0)
                : "—"
            cell.textField?.alignment = .right
        default:
            cell.textField?.stringValue = item.displayTitle
            cell.textField?.toolTip = item.manualDownloadURL ?? item.linkURL
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        if table === itemsTable {
            selectedItemIDs = Set(table.selectedRowIndexes.compactMap { index -> String? in
                let items = currentItems
                guard index >= 0, index < items.count else { return nil }
                return items[index].id
            })
            updateButtons()
            return
        }
        if table === feedTable, table.selectedRow >= 0, table.selectedRow < feeds.count {
            selectedFeedID = feeds[table.selectedRow].id
            updateSelectedFeed()
        }
    }

    private static func makeTextCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11.5)
        label.lineBreakMode = .byTruncatingTail
        cell.textField = label
        cell.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(2)
            make.centerY.equalToSuperview()
        }
        return cell
    }
}

extension DownloadRSSSheetViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard (obj.object as? NSTextField) === keywordField else { return }
        applyKeywordsTapped()
    }
}

// MARK: - Feed cell

private final class RSSFeedCellView: NSTableCellView {

    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let autoLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = .systemFont(ofSize: 10)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingMiddle
        autoLabel.font = .systemFont(ofSize: 9.5, weight: .medium)
        autoLabel.textColor = .controlAccentColor
        autoLabel.alignment = .right

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(autoLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.trailing.equalTo(autoLabel.snp.leading).offset(-6)
            make.top.equalToSuperview().offset(7)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-4)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }
        autoLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(66)
        }
    }

    func configure(feed: RSSFeedSubscription) {
        titleLabel.stringValue = feed.displayTitle
        titleLabel.toolTip = feed.title
        subtitleLabel.stringValue = feed.url
        subtitleLabel.toolTip = feed.url
        autoLabel.stringValue = feed.isAutoDownloadEnabled
            ? NSLocalizedString("自动下载", comment: "")
            : ""
    }
}
