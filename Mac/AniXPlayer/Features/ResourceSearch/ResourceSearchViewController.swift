//
//  ResourceSearchViewController.swift
//  AniXPlayer
//
//  macOS：资源搜索页（res.dandanplay.net）。按关键词搜索资源并通过下载中心下载种子/磁力。
//

import Cocoa
import SnapKit

final class ResourceSearchViewController: ViewController {

    /// 交给主窗口：切到下载中心并预填磁力/种子地址。
    var onDownload: ((ResourceSearchItem) -> Void)?

    private let service = ResourceSearchService.shared

    private var searchTask: Task<Void, Never>?
    private var filtersTask: Task<Void, Never>?
    private var allItems: [ResourceSearchItem] = []
    private var items: [ResourceSearchItem] = []
    private var typeOptions: [ResourceSearchOption] = []
    private var subgroupOptions: [ResourceSearchOption] = []
    private var lastKeyword = ""
    private var hasMore = false
    private var isSearching = false
    private var didFocusOnFirstAppearance = false

    // MARK: Views

    private lazy var titleLabel: Label = {
        let label = welcomeShellLabel(
            NSLocalizedString("资源搜索", comment: ""),
            font: .systemFont(ofSize: 24, weight: .bold),
            color: .labelColor
        )
        label.setAccessibilityIdentifier(AccessibilityID.ResourceSearch.pageTitle)
        return label
    }()

    private lazy var subtitleLabel: Label = {
        return welcomeShellLabel(
            NSLocalizedString("搜索动画、漫画、音乐等资源", comment: ""),
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )
    }()

    private lazy var searchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = NSLocalizedString("搜索资源名称、字幕组或关键词", comment: "")
        field.font = .systemFont(ofSize: 13)
        field.sendsWholeSearchString = true
        field.sendsSearchStringImmediately = false
        field.target = self
        field.action = #selector(performSearch)
        field.recentsAutosaveName = "AniXPlayer.ResourceSearch"
        field.setAccessibilityIdentifier(AccessibilityID.ResourceSearch.searchField)
        field.setAccessibilityLabel(NSLocalizedString("资源搜索关键词", comment: ""))
        return field
    }()

    private lazy var searchButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("搜索", comment: ""),
            target: self,
            action: #selector(performSearch)
        )
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.setAccessibilityIdentifier(AccessibilityID.ResourceSearch.searchButton)
        return button
    }()

    private lazy var typeFilter: NSPopUpButton = {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItem(withTitle: NSLocalizedString("全部分类", comment: ""))
        popup.target = self
        popup.action = #selector(filterChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.ResourceSearch.typeFilter)
        popup.setAccessibilityLabel(NSLocalizedString("资源分类", comment: ""))
        return popup
    }()

    private lazy var subgroupFilter: NSPopUpButton = {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItem(withTitle: NSLocalizedString("全部字幕组", comment: ""))
        popup.target = self
        popup.action = #selector(filterChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.ResourceSearch.subgroupFilter)
        popup.setAccessibilityLabel(NSLocalizedString("字幕组", comment: ""))
        return popup
    }()

    private lazy var statusLabel: Label = {
        let label = welcomeShellLabel(
            "",
            font: .systemFont(ofSize: 11.5),
            color: .secondaryLabelColor
        )
        label.setAccessibilityIdentifier(AccessibilityID.ResourceSearch.status)
        return label
    }()

    private lazy var spinner: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isDisplayedWhenStopped = false
        return indicator
    }()

    private let tableContainer = ResourceSearchTableContainerView()
    private lazy var tableScroll: NSScrollView = {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.documentView = tableView
        return scroll
    }()

    private lazy var tableView: NSTableView = {
        let table = NSTableView()
        table.dataSource = self
        table.delegate = self
        table.headerView = NSTableHeaderView()
        table.rowHeight = 38
        table.intercellSpacing = NSSize(width: 8, height: 0)
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        table.usesAlternatingRowBackgroundColors = false
        table.backgroundColor = .clear
        table.gridStyleMask = [.solidHorizontalGridLineMask]
        table.allowsMultipleSelection = false
        table.allowsEmptySelection = true
        table.target = self
        table.doubleAction = #selector(downloadSelectedRow)
        table.setAccessibilityIdentifier(AccessibilityID.ResourceSearch.table)
        table.setAccessibilityLabel(NSLocalizedString("资源搜索结果", comment: ""))
        return table
    }()

    private lazy var emptyStateView: WelcomeShellStateView = {
        let view = WelcomeShellStateView()
        view.setAccessibilityIdentifier(AccessibilityID.ResourceSearch.emptyState)
        return view
    }()

    private lazy var helpLabel: Label = {
        return welcomeShellLabel(
            NSLocalizedString("关键词支持：空格表示“与”，| 表示“或”，! 表示排除。例如：eva 01", comment: ""),
            font: .systemFont(ofSize: 10.5),
            color: .tertiaryLabelColor
        )
    }()

    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        let downloadItem = NSMenuItem(
            title: NSLocalizedString("下载", comment: ""),
            action: #selector(downloadContextRow),
            keyEquivalent: ""
        )
        downloadItem.target = self
        menu.addItem(downloadItem)
        let copyItem = NSMenuItem(
            title: NSLocalizedString("复制磁力链接", comment: ""),
            action: #selector(copyMagnetContextRow),
            keyEquivalent: ""
        )
        copyItem.target = self
        menu.addItem(copyItem)
        menu.addItem(.separator())
        let pageItem = NSMenuItem(
            title: NSLocalizedString("打开发布页", comment: ""),
            action: #selector(openPageContextRow),
            keyEquivalent: ""
        )
        pageItem.target = self
        menu.addItem(pageItem)
        return menu
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("资源搜索", comment: "")
        view.setAccessibilityIdentifier(AccessibilityID.ResourceSearch.root)
        setupLayout()
        setupTable()
        showInitialState()
        loadFilters()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !didFocusOnFirstAppearance, searchField.stringValue.isEmpty else { return }
        didFocusOnFirstAppearance = true
        focusSearchField()
    }

    deinit {
        searchTask?.cancel()
        filtersTask?.cancel()
    }

    // MARK: Public

    func focusSearchField() {
        _ = view
        view.window?.makeFirstResponder(searchField)
    }

    /// 外部入口（详情页等）：预填关键词并立即搜索。
    func applyExternalSearch(_ keyword: String) {
        _ = view
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            focusSearchField()
            return
        }
        searchField.stringValue = trimmed
        performSearch()
    }

    // MARK: Setup

    private func setupLayout() {
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(searchField)
        view.addSubview(searchButton)
        view.addSubview(typeFilter)
        view.addSubview(subgroupFilter)
        view.addSubview(statusLabel)
        view.addSubview(spinner)
        view.addSubview(tableContainer)
        view.addSubview(helpLabel)

        tableContainer.wantsLayer = true
        tableContainer.layer?.cornerRadius = 10
        tableContainer.layer?.cornerCurve = .continuous
        tableContainer.layer?.borderWidth = 1
        tableContainer.onAppearanceChange = { [weak self] in
            self?.updateTableContainerColors()
        }
        updateTableContainerColors()

        tableContainer.addSubview(tableScroll)
        tableContainer.addSubview(emptyStateView)

        tableScroll.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyStateView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.top.equalToSuperview().offset(16)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.trailing.lessThanOrEqualToSuperview().offset(-22)
        }

        searchField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(14)
            make.height.equalTo(28)
        }
        searchButton.snp.makeConstraints { make in
            make.leading.equalTo(searchField.snp.trailing).offset(8)
            make.trailing.equalTo(typeFilter.snp.leading).offset(-8)
            make.centerY.equalTo(searchField)
            make.width.equalTo(64)
        }
        subgroupFilter.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-22)
            make.centerY.equalTo(searchField)
            make.width.equalTo(176)
        }
        typeFilter.snp.makeConstraints { make in
            make.trailing.equalTo(subgroupFilter.snp.leading).offset(-8)
            make.centerY.equalTo(searchField)
            make.width.equalTo(140)
        }

        spinner.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-22)
            make.centerY.equalTo(statusLabel)
            make.width.height.equalTo(14)
        }
        statusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.top.equalTo(searchField.snp.bottom).offset(10)
            make.trailing.lessThanOrEqualTo(spinner.snp.leading).offset(-8)
        }

        tableContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.trailing.equalToSuperview().offset(-22)
            make.top.equalTo(statusLabel.snp.bottom).offset(8)
            make.bottom.equalTo(helpLabel.snp.top).offset(-8)
        }
        helpLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.trailing.lessThanOrEqualToSuperview().offset(-22)
            make.bottom.equalToSuperview().offset(-10)
        }
    }

    private func setupTable() {
        let columns: [(String, String, CGFloat, CGFloat, NSTableColumn.ResizingOptions)] = [
            ("title", NSLocalizedString("资源名称", comment: ""), 380, 220, [.autoresizingMask]),
            ("type", NSLocalizedString("类型", comment: ""), 96, 70, []),
            ("subgroup", NSLocalizedString("字幕组", comment: ""), 120, 80, []),
            ("size", NSLocalizedString("大小", comment: ""), 64, 54, []),
            ("date", NSLocalizedString("发布时间", comment: ""), 136, 110, []),
            ("actions", NSLocalizedString("操作", comment: ""), 104, 96, []),
        ]
        for (identifier, title, width, minWidth, resizingMask) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.minWidth = minWidth
            column.resizingMask = resizingMask
            tableView.addTableColumn(column)
        }
        tableView.menu = contextMenu
    }

    private func updateTableContainerColors() {
        tableContainer.effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }
            self.tableContainer.layer?.backgroundColor = NSColor.controlBackgroundColor
                .withAlphaComponent(0.52)
                .cgColor
            self.tableContainer.layer?.borderColor = NSColor.separatorColor
                .withAlphaComponent(0.35)
                .cgColor
            self.tableView.gridColor = NSColor.separatorColor.withAlphaComponent(0.22)
        }
    }

    // MARK: Filters

    private func loadFilters() {
        filtersTask?.cancel()
        filtersTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            async let typesTask = self.service.fetchTypeOptions()
            async let subgroupsTask = self.service.fetchSubgroupOptions()
            let types = try? await typesTask
            let subgroups = try? await subgroupsTask
            guard !Task.isCancelled else { return }
            if let types = types {
                self.typeOptions = types
            }
            if let subgroups = subgroups {
                self.subgroupOptions = subgroups
            }
            self.rebuildFilterPopups()
        }
    }

    private func rebuildFilterPopups() {
        let previousTypeId = selectedTypeId
        let previousSubgroupId = selectedSubgroupId

        typeFilter.removeAllItems()
        typeFilter.addItem(withTitle: NSLocalizedString("全部分类", comment: ""))
        for option in typeOptions {
            typeFilter.addItem(withTitle: option.name)
        }
        if let previousTypeId = previousTypeId,
           let index = typeOptions.firstIndex(where: { $0.id == previousTypeId }) {
            typeFilter.selectItem(at: index + 1)
        } else {
            typeFilter.selectItem(at: 0)
        }

        subgroupFilter.removeAllItems()
        subgroupFilter.addItem(withTitle: NSLocalizedString("全部字幕组", comment: ""))
        for option in subgroupOptions {
            subgroupFilter.addItem(withTitle: option.name)
        }
        if let previousSubgroupId = previousSubgroupId,
           let index = subgroupOptions.firstIndex(where: { $0.id == previousSubgroupId }) {
            subgroupFilter.selectItem(at: index + 1)
        } else {
            subgroupFilter.selectItem(at: 0)
        }
    }

    private var selectedTypeId: Int? {
        let index = typeFilter.indexOfSelectedItem
        guard index > 0, index - 1 < typeOptions.count else { return nil }
        return typeOptions[index - 1].id
    }

    private var selectedSubgroupId: Int? {
        let index = subgroupFilter.indexOfSelectedItem
        guard index > 0, index - 1 < subgroupOptions.count else { return nil }
        return subgroupOptions[index - 1].id
    }

    private var currentFilter: ResourceSearchFilter {
        ResourceSearchFilter(typeId: selectedTypeId, subgroupId: selectedSubgroupId)
    }

    @objc private func filterChanged() {
        // 分类/字幕组会参与服务端搜索，已有关键词时重新请求，避免只过滤前 200 条。
        guard !lastKeyword.isEmpty else {
            updateStatus()
            return
        }
        performSearch()
    }

    // MARK: Search

    @objc private func performSearch() {
        let keyword = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            searchTask?.cancel()
            isSearching = false
            lastKeyword = ""
            hasMore = false
            allItems = []
            items = []
            tableView.reloadData()
            focusSearchField()
            showInitialState()
            return
        }

        searchTask?.cancel()
        lastKeyword = keyword
        isSearching = true
        allItems = []
        items = []
        tableView.reloadData()
        showLoadingState()
        updateStatus()

        let typeId = selectedTypeId
        let subgroupId = selectedSubgroupId
        searchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let response = try await self.service.search(
                    keyword: keyword,
                    typeId: typeId,
                    subgroupId: subgroupId
                )
                guard !Task.isCancelled else { return }
                self.isSearching = false
                self.hasMore = response.hasMore
                self.allItems = response.resources
                self.applyFilters()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.isSearching = false
                self.hasMore = false
                self.allItems = []
                self.items = []
                self.tableView.reloadData()
                self.showErrorState(error.localizedDescription)
                self.updateStatus()
            }
        }
    }

    private func applyFilters() {
        let filter = currentFilter
        items = filter.apply(to: allItems)
        tableView.reloadData()
        if !allItems.isEmpty, !items.isEmpty {
            tableScroll.isHidden = false
            emptyStateView.isHidden = true
        } else {
            updateEmptyStateForFilter()
        }
        updateStatus()
    }

    // MARK: States

    private func showInitialState() {
        spinner.stopAnimation(nil)
        tableScroll.isHidden = true
        emptyStateView.isHidden = false
        emptyStateView.configure(
            title: NSLocalizedString("搜索弹弹play 资源", comment: ""),
            detail: NSLocalizedString("输入作品名、字幕组或关键词，回车开始搜索。", comment: "")
        )
        statusLabel.text = NSLocalizedString("支持磁力链接与种子下载", comment: "")
    }

    private func showLoadingState() {
        spinner.startAnimation(nil)
        tableScroll.isHidden = true
        emptyStateView.isHidden = false
        emptyStateView.configure(
            title: NSLocalizedString("正在搜索…", comment: ""),
            detail: NSLocalizedString("正在从资源服务器获取结果。", comment: "")
        )
    }

    private func showErrorState(_ message: String) {
        spinner.stopAnimation(nil)
        tableScroll.isHidden = true
        emptyStateView.isHidden = false
        emptyStateView.configure(
            title: NSLocalizedString("资源搜索失败", comment: ""),
            detail: message,
            actionTitle: NSLocalizedString("重试", comment: ""),
            onAction: { [weak self] in
                self?.performSearch()
            }
        )
    }

    private func updateEmptyStateForFilter() {
        spinner.stopAnimation(nil)
        if allItems.isEmpty {
            tableScroll.isHidden = true
            emptyStateView.isHidden = false
            emptyStateView.configure(
                title: NSLocalizedString("没有找到资源", comment: ""),
                detail: NSLocalizedString("试试更短的关键词，或使用作品别名/简称。", comment: ""),
                actionTitle: NSLocalizedString("重试", comment: ""),
                onAction: { [weak self] in
                    self?.performSearch()
                }
            )
        } else if items.isEmpty {
            tableScroll.isHidden = true
            emptyStateView.isHidden = false
            emptyStateView.configure(
                title: NSLocalizedString("当前筛选条件下没有资源", comment: ""),
                detail: NSLocalizedString("切换分类或字幕组试试。", comment: ""),
                actionTitle: NSLocalizedString("清除筛选", comment: ""),
                onAction: { [weak self] in
                    self?.clearFilters()
                }
            )
        } else {
            tableScroll.isHidden = false
            emptyStateView.isHidden = true
        }
    }

    private func updateStatus() {
        if isSearching {
            spinner.startAnimation(nil)
            statusLabel.text = NSLocalizedString("正在搜索…", comment: "")
            return
        }

        spinner.stopAnimation(nil)
        guard !allItems.isEmpty else {
            if lastKeyword.isEmpty {
                statusLabel.text = NSLocalizedString("支持磁力链接与种子下载", comment: "")
            } else {
                statusLabel.text = NSLocalizedString("0 条资源", comment: "")
            }
            return
        }

        var text: String
        if currentFilter.isActive, items.count != allItems.count {
            text = String(
                format: NSLocalizedString("找到 %d 条资源（共 %d 条）", comment: ""),
                items.count,
                allItems.count
            )
        } else {
            text = String(
                format: NSLocalizedString("找到 %d 条资源", comment: ""),
                items.count
            )
        }
        if hasMore {
            text += " · " + NSLocalizedString("结果较多，可加关键词缩小范围", comment: "")
        }
        statusLabel.text = text
    }

    private func clearFilters() {
        typeFilter.selectItem(at: 0)
        subgroupFilter.selectItem(at: 0)
        if lastKeyword.isEmpty {
            updateStatus()
        } else {
            performSearch()
        }
    }

    // MARK: Actions

    private func itemForContextMenu() -> ResourceSearchItem? {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < items.count else { return nil }
        return items[row]
    }

    private func download(_ item: ResourceSearchItem) {
        guard item.downloadSource != nil else {
            view.show(text: NSLocalizedString("该资源没有可用的磁力链接或种子下载地址。", comment: ""))
            return
        }
        onDownload?(item)
    }

    @objc private func downloadSelectedRow() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < items.count else { return }
        download(items[row])
    }

    @objc private func downloadContextRow() {
        guard let item = itemForContextMenu() else { return }
        download(item)
    }

    @objc private func copyMagnetContextRow() {
        guard let item = itemForContextMenu() else { return }
        let magnet = item.magnet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !magnet.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(magnet, forType: .string)
        view.show(text: NSLocalizedString("已复制磁力链接", comment: ""))
    }

    @objc private func openPageContextRow() {
        guard let item = itemForContextMenu(),
              let rawURL = item.pageUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty,
              let url = URL(string: rawURL) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openPage(_ item: ResourceSearchItem) {
        guard let rawURL = item.pageUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty,
              let url = URL(string: rawURL) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: Cells

    private func textCell(identifier: String) -> NSTableCellView {
        let cellIdentifier = NSUserInterfaceItemIdentifier("resourceSearch.cell.\(identifier)")
        if let reused = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            return reused
        }
        let cell = NSTableCellView()
        cell.identifier = cellIdentifier
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11.5)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        cell.textField = label
        cell.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(2)
            make.centerY.equalToSuperview()
        }
        return cell
    }

    private func actionsCell(for item: ResourceSearchItem) -> ResourceSearchActionsCell {
        let identifier = NSUserInterfaceItemIdentifier("resourceSearch.cell.actions")
        let cell: ResourceSearchActionsCell
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? ResourceSearchActionsCell {
            cell = reused
        } else {
            cell = ResourceSearchActionsCell()
            cell.identifier = identifier
        }
        cell.configure(item: item)
        cell.onDownload = { [weak self] item in
            self?.download(item)
        }
        cell.onOpenPage = { [weak self] item in
            self?.openPage(item)
        }
        return cell
    }
}

// MARK: - Table

extension ResourceSearchViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }
}

extension ResourceSearchViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn, row < items.count else { return nil }
        let item = items[row]

        if tableColumn.identifier.rawValue == "actions" {
            return actionsCell(for: item)
        }

        let cell = textCell(identifier: tableColumn.identifier.rawValue)
        guard let label = cell.textField else { return cell }

        switch tableColumn.identifier.rawValue {
        case "title":
            label.stringValue = item.title
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = .labelColor
            label.toolTip = item.title
        case "type":
            label.stringValue = item.displayTypeName
            label.font = .systemFont(ofSize: 11.5)
            label.textColor = .secondaryLabelColor
            label.toolTip = item.displayTypeName
        case "subgroup":
            label.stringValue = item.displaySubgroupName
            label.font = .systemFont(ofSize: 11.5)
            label.textColor = .secondaryLabelColor
            label.toolTip = item.displaySubgroupName
        case "size":
            label.stringValue = item.displayFileSize
            label.font = .systemFont(ofSize: 11.5)
            label.textColor = .secondaryLabelColor
            label.alignment = .right
        case "date":
            label.stringValue = item.displayPublishDate
            label.font = .systemFont(ofSize: 11.5)
            label.textColor = .secondaryLabelColor
        default:
            label.stringValue = ""
        }
        return cell
    }
}

// MARK: - Context menu

extension ResourceSearchViewController: NSMenuDelegate, NSMenuItemValidation {

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let item = itemForContextMenu() else { return }
        for menuItem in menu.items {
            switch menuItem.action {
            case #selector(copyMagnetContextRow):
                menuItem.isEnabled = !item.magnet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case #selector(openPageContextRow):
                menuItem.isEnabled = !(item.pageUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case #selector(downloadContextRow):
                menuItem.isEnabled = item.downloadSource != nil
            default:
                break
            }
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let item = itemForContextMenu() else { return false }
        switch menuItem.action {
        case #selector(copyMagnetContextRow):
            return !item.magnet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case #selector(openPageContextRow):
            return !(item.pageUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case #selector(downloadContextRow):
            return item.downloadSource != nil
        default:
            return true
        }
    }
}

// MARK: - Table container

private final class ResourceSearchTableContainerView: NSView {

    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}

// MARK: - Actions cell

private final class ResourceSearchActionButton: NSButton {

    var onClick: (() -> Void)?

    init(title: String, image: NSImage? = nil) {
        super.init(frame: .zero)
        self.title = title
        self.image = image
        target = self
        action = #selector(handleClick)
        bezelStyle = image == nil ? .rounded : .inline
        focusRingType = .none
        controlSize = image == nil ? .small : .regular
        if image != nil {
            isBordered = false
            imagePosition = .imageOnly
            contentTintColor = .secondaryLabelColor
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleClick() {
        onClick?()
    }
}

private final class ResourceSearchActionsCell: NSTableCellView {

    var onDownload: ((ResourceSearchItem) -> Void)?
    var onOpenPage: ((ResourceSearchItem) -> Void)?

    private let downloadButton = ResourceSearchActionButton(
        title: NSLocalizedString("下载", comment: "")
    )
    private let pageButton = ResourceSearchActionButton(
        title: "",
        image: welcomeShellSymbol("arrow.up.right.square", pointSize: 13, weight: .medium)
    )
    private var item: ResourceSearchItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        pageButton.toolTip = NSLocalizedString("打开发布页", comment: "")
        pageButton.setAccessibilityLabel(NSLocalizedString("打开发布页", comment: ""))
        downloadButton.setAccessibilityLabel(NSLocalizedString("下载", comment: ""))

        let stack = NSStackView(views: [downloadButton, pageButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(2)
            make.centerY.equalToSuperview()
        }
        downloadButton.snp.makeConstraints { make in
            make.width.equalTo(52)
            make.height.equalTo(22)
        }
        pageButton.snp.makeConstraints { make in
            make.width.height.equalTo(22)
        }

        downloadButton.onClick = { [weak self] in
            guard let self = self, let item = self.item else { return }
            self.onDownload?(item)
        }
        pageButton.onClick = { [weak self] in
            guard let self = self, let item = self.item else { return }
            self.onOpenPage?(item)
        }
    }

    func configure(item: ResourceSearchItem) {
        self.item = item
        downloadButton.isEnabled = item.downloadSource != nil
        downloadButton.toolTip = item.downloadSource == nil
            ? NSLocalizedString("该资源没有可用的磁力链接或种子下载地址。", comment: "")
            : nil
        let hasPage = !(item.pageUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        pageButton.isHidden = !hasPage
        setAccessibilityIdentifier(AccessibilityID.ResourceSearch.rowPrefix + item.id)
    }
}
