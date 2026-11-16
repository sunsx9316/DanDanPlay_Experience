//
//  DanmakuListViewController.swift
//  AniXPlayer
//
//  macOS only：播放器「弹幕设置 → 弹幕列表」独立窗口。
//

import Cocoa
import SnapKit

final class DanmakuListViewController: ViewController {

    /// 双击弹幕或右键「跳转到这个时间」时回调播放器。
    var onSeek: ((TimeInterval) -> Void)?

    private let danmakuModel: PlayerDanmakuModel

    private var matchDescription: String?
    private var isLoading = false

    private var allEntries: [DanmakuListEntry] = []
    private var visibleEntries: [DanmakuListEntry] = []

    private var windowObserver: NSObjectProtocol?

    private static let timeColumnIdentifier = NSUserInterfaceItemIdentifier("danmakuList.time")
    private static let textColumnIdentifier = NSUserInterfaceItemIdentifier("danmakuList.text")

    // MARK: - Views

    private lazy var matchLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12.5, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListMatch)
        return label
    }()

    private lazy var summaryLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        label.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListSummary)
        return label
    }()

    private lazy var searchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = NSLocalizedString("搜索弹幕内容", comment: "")
        field.font = .systemFont(ofSize: 12.5)
        field.sendsWholeSearchString = false
        field.sendsSearchStringImmediately = true
        field.target = self
        field.action = #selector(searchChanged)
        field.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListSearchField)
        field.setAccessibilityLabel(NSLocalizedString("搜索弹幕内容", comment: ""))
        return field
    }()

    private lazy var tableView: TableView = {
        let table = TableView()
        table.dataSource = self
        table.delegate = self
        table.headerView = NSTableHeaderView()
        table.rowHeight = 26
        table.intercellSpacing = NSSize(width: 8, height: 0)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.usesAlternatingRowBackgroundColors = true
        table.gridStyleMask = [.solidHorizontalGridLineMask]
        table.allowsMultipleSelection = false
        table.allowsEmptySelection = true
        table.target = self
        table.doubleAction = #selector(handleDoubleClick)
        table.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListTable)
        table.setAccessibilityLabel(NSLocalizedString("弹幕列表", comment: ""))
        table.menu = contextMenu
        return table
    }()

    private lazy var scrollView: ScrollView<TableView> = {
        let scrollView = ScrollView(containerView: tableView)
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        return scrollView
    }()

    private lazy var emptyTitleLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        return label
    }()

    private lazy var emptyDetailLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        return label
    }()

    private lazy var emptyActionButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("清除搜索", comment: ""),
            target: self,
            action: #selector(clearSearch)
        )
        button.bezelStyle = .rounded
        button.controlSize = .small
        return button
    }()

    private lazy var loadingIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isDisplayedWhenStopped = false
        indicator.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListLoading)
        return indicator
    }()

    private lazy var emptyStateView: NSView = {
        let container = NSView()
        container.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListEmptyState)

        let stack = NSStackView(views: [
            loadingIndicator,
            emptyTitleLabel,
            emptyDetailLabel,
            emptyActionButton
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        container.addSubview(stack)

        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(36)
            make.trailing.equalToSuperview().offset(-36)
            make.centerY.equalToSuperview()
        }
        emptyTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
        emptyDetailLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
        return container
    }()

    private lazy var statusLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListStatus)
        return label
    }()

    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self

        let copyItem = NSMenuItem(
            title: NSLocalizedString("复制弹幕", comment: ""),
            action: #selector(copyContextEntry),
            keyEquivalent: ""
        )
        copyItem.target = self
        menu.addItem(copyItem)

        let seekItem = NSMenuItem(
            title: NSLocalizedString("跳转到这个时间", comment: ""),
            action: #selector(seekContextEntry),
            keyEquivalent: ""
        )
        seekItem.target = self
        menu.addItem(seekItem)

        menu.addItem(.separator())

        let blockItem = NSMenuItem(
            title: NSLocalizedString("屏蔽该弹幕文本", comment: ""),
            action: #selector(blockContextEntry),
            keyEquivalent: ""
        )
        blockItem.target = self
        menu.addItem(blockItem)

        // TODO: 模型暂不支持按单条删除、按 userId 屏蔽；待弹幕数据模型补齐后再加入菜单。

        return menu
    }()

    // MARK: - Lifecycle

    init(danmakuModel: PlayerDanmakuModel) {
        self.danmakuModel = danmakuModel
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
        }
    }

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 560, height: 520))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("弹幕列表", comment: "")
        self.view.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListRoot)

        self.setupLayout()
        self.refresh()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if let window = self.view.window, self.windowObserver == nil {
            self.windowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
            self.windowObserver = nil
        }
    }

    // MARK: - Public

    /// 由播放器同步当前匹配信息与加载状态。
    func update(matchDescription: String?, isLoading: Bool) {
        self.matchDescription = matchDescription
        self.isLoading = isLoading
        self.refresh()
    }

    /// 重新读取播放器弹幕数据、屏蔽规则与搜索关键词。
    func refresh() {
        guard self.isViewLoaded else { return }

        let rules = self.currentFilterRules()
        let entries = self.danmakuModel.danmakuList.map { entity -> DanmakuListEntry in
            let rawComment = entity.rawComment
            let time = DanmakuListLogic.resolvedTime(
                originAppearTime: entity.originAppearTime,
                rawCommentTime: rawComment?.time,
                appearTime: entity.appearTime
            )
            return DanmakuListEntry(
                time: time,
                text: entity.text,
                isFiltered: entity.isFilter,
                userId: rawComment?.userId ?? entity.userId,
                source: rawComment?.source ?? "",
                commentId: rawComment?.id ?? 0
            )
        }

        self.allEntries = DanmakuListLogic.prepared(entries, filterRules: rules)
        self.applySearch()
    }

    // MARK: - Setup

    private func setupLayout() {
        self.view.addSubview(self.matchLabel)
        self.view.addSubview(self.summaryLabel)
        self.view.addSubview(self.searchField)
        self.view.addSubview(self.scrollView)
        self.view.addSubview(self.emptyStateView)
        self.view.addSubview(self.statusLabel)

        self.matchLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
        }

        self.summaryLabel.snp.makeConstraints { make in
            make.leading.equalTo(self.matchLabel)
            make.top.equalTo(self.matchLabel.snp.bottom).offset(4)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
        }

        self.searchField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalTo(self.summaryLabel.snp.bottom).offset(12)
            make.height.equalTo(26)
        }

        self.scrollView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalTo(self.searchField.snp.bottom).offset(10)
            make.bottom.equalTo(self.statusLabel.snp.top).offset(-10)
        }

        self.emptyStateView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(self.scrollView)
            make.top.bottom.equalTo(self.scrollView)
        }

        self.statusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-12)
        }

        let timeColumn = NSTableColumn(identifier: Self.timeColumnIdentifier)
        timeColumn.title = NSLocalizedString("时间（mm:ss）", comment: "")
        timeColumn.width = 104
        timeColumn.minWidth = 84
        timeColumn.maxWidth = 150
        timeColumn.resizingMask = []
        self.tableView.addTableColumn(timeColumn)

        let textColumn = NSTableColumn(identifier: Self.textColumnIdentifier)
        textColumn.title = NSLocalizedString("弹幕", comment: "")
        textColumn.width = 390
        textColumn.minWidth = 160
        textColumn.resizingMask = .autoresizingMask
        self.tableView.addTableColumn(textColumn)
    }

    // MARK: - Data

    private func currentFilterRules() -> [DanmakuListFilterRule] {
        return (self.danmakuModel.filterDanmakus ?? []).compactMap { filter in
            guard let text = filter.text else { return nil }
            return DanmakuListFilterRule(
                text: text,
                isRegularExpression: filter.isRegularExp,
                isEnabled: filter.isEnable
            )
        }
    }

    private func applySearch() {
        self.visibleEntries = DanmakuListLogic.searched(
            self.allEntries,
            text: self.searchField.stringValue
        )
        self.updateHeader()
        self.updateTableState()
        self.tableView.reloadData()
    }

    private func updateHeader() {
        if let matchDescription, !matchDescription.isEmpty {
            self.matchLabel.text = String(
                format: NSLocalizedString("已关联弹幕库：%@", comment: ""),
                matchDescription
            )
        } else if !self.allEntries.isEmpty {
            self.matchLabel.text = NSLocalizedString("已加载本地弹幕", comment: "")
        } else if self.isLoading {
            self.matchLabel.text = NSLocalizedString("正在匹配弹幕库…", comment: "")
        } else {
            self.matchLabel.text = NSLocalizedString("尚未关联弹幕库", comment: "")
        }

        let filteredCount = DanmakuListLogic.filteredCount(self.allEntries)
        self.summaryLabel.text = String(
            format: NSLocalizedString("弹幕 %d 条 · 已过滤 %d 条", comment: ""),
            self.allEntries.count,
            filteredCount
        )
        self.statusLabel.text = String(
            format: NSLocalizedString("显示 %d / %d 条", comment: ""),
            self.visibleEntries.count,
            self.allEntries.count
        )
    }

    private func updateTableState() {
        if !self.allEntries.isEmpty, !self.visibleEntries.isEmpty {
            self.scrollView.isHidden = false
            self.emptyStateView.isHidden = true
            return
        }

        self.scrollView.isHidden = true
        self.emptyStateView.isHidden = false

        let keyword = self.searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !self.allEntries.isEmpty, !keyword.isEmpty {
            self.showEmptyState(
                title: NSLocalizedString("没有匹配搜索内容的弹幕", comment: ""),
                detail: NSLocalizedString("清空搜索框可恢复全部弹幕。", comment: ""),
                showsAction: true,
                showsLoading: false
            )
        } else if self.isLoading, self.allEntries.isEmpty {
            self.showEmptyState(
                title: NSLocalizedString("正在加载弹幕…", comment: ""),
                detail: NSLocalizedString("弹幕加载完成后会显示在这里。", comment: ""),
                showsAction: false,
                showsLoading: true
            )
        } else if self.matchDescription == nil, self.allEntries.isEmpty {
            self.showEmptyState(
                title: NSLocalizedString("尚未关联弹幕库", comment: ""),
                detail: NSLocalizedString("当前视频没有匹配到弹幕库。", comment: ""),
                showsAction: false,
                showsLoading: false
            )
        } else {
            self.showEmptyState(
                title: NSLocalizedString("当前没有弹幕", comment: ""),
                detail: NSLocalizedString("当前视频没有可显示的弹幕。", comment: ""),
                showsAction: false,
                showsLoading: false
            )
        }
    }

    private func showEmptyState(title: String, detail: String, showsAction: Bool, showsLoading: Bool) {
        self.emptyTitleLabel.text = title
        self.emptyDetailLabel.text = detail
        self.emptyActionButton.isHidden = !showsAction

        if showsLoading {
            self.loadingIndicator.startAnimation(nil)
        } else {
            self.loadingIndicator.stopAnimation(nil)
        }
        self.loadingIndicator.isHidden = !showsLoading
    }

    // MARK: - Actions

    private var contextEntry: DanmakuListEntry? {
        let row = self.tableView.clickedRow >= 0 ? self.tableView.clickedRow : self.tableView.selectedRow
        guard row >= 0, row < self.visibleEntries.count else { return nil }
        return self.visibleEntries[row]
    }

    @objc private func searchChanged() {
        self.applySearch()
    }

    @objc private func clearSearch() {
        self.searchField.stringValue = ""
        self.applySearch()
        self.view.window?.makeFirstResponder(self.searchField)
    }

    @objc private func handleDoubleClick() {
        let row = self.tableView.clickedRow
        guard row >= 0, row < self.visibleEntries.count else { return }
        self.seek(to: self.visibleEntries[row])
    }

    @objc private func copyContextEntry() {
        guard let entry = self.contextEntry else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        self.view.show(text: NSLocalizedString("已复制弹幕", comment: ""))
    }

    @objc private func seekContextEntry() {
        guard let entry = self.contextEntry else { return }
        self.seek(to: entry)
    }

    @objc private func blockContextEntry() {
        guard let entry = self.contextEntry else { return }
        self.danmakuModel.onAddFilterDanmku(entry.text)
        self.refresh()
        self.view.show(text: NSLocalizedString("已屏蔽该弹幕文本", comment: ""))
    }

    private func seek(to entry: DanmakuListEntry) {
        self.onSeek?(entry.time)
    }
}

// MARK: - Table

extension DanmakuListViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.visibleEntries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, row < self.visibleEntries.count else { return nil }
        let entry = self.visibleEntries[row]
        let isTimeColumn = tableColumn.identifier == Self.timeColumnIdentifier

        let cellIdentifier = NSUserInterfaceItemIdentifier(
            isTimeColumn ? "danmakuList.cell.time" : "danmakuList.cell.text"
        )
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellIdentifier
            let label = NSTextField(labelWithString: "")
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            cell.textField = label
            cell.addSubview(label)
            label.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(4)
                make.centerY.equalToSuperview()
            }
        }

        guard let label = cell.textField else { return cell }

        if isTimeColumn {
            label.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
            label.textColor = entry.isFiltered ? .tertiaryLabelColor : .secondaryLabelColor
            label.stringValue = DanmakuListLogic.formattedTime(entry.time)
            label.toolTip = nil
        } else {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: entry.isFiltered ? NSColor.secondaryLabelColor : NSColor.labelColor,
                .strikethroughStyle: entry.isFiltered ? NSUnderlineStyle.single.rawValue : 0
            ]
            label.attributedStringValue = NSAttributedString(string: entry.text, attributes: attributes)
            label.toolTip = entry.text
        }

        cell.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListRowPrefix + "\(row)")
        cell.setAccessibilityLabel(entry.text)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = tableView.themedRowView(forRow: row)
        rowView.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListRowPrefix + "\(row)")
        return rowView
    }
}

// MARK: - Context menu

extension DanmakuListViewController: NSMenuDelegate, NSMenuItemValidation {

    func menuNeedsUpdate(_ menu: NSMenu) {
        let hasEntry = self.contextEntry != nil
        menu.items.forEach { $0.isEnabled = hasEntry }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return self.contextEntry != nil
    }
}

// MARK: - Window

/// 独立非模态窗口；由 `PlayerViewController` 持有，播放器关闭时同步关闭。
@MainActor
final class DanmakuListWindowController: NSWindowController, NSWindowDelegate {

    let listViewController: DanmakuListViewController

    var onClose: (() -> Void)?

    init(danmakuModel: PlayerDanmakuModel) {
        let contentViewController = DanmakuListViewController(danmakuModel: danmakuModel)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("弹幕列表", comment: "")
        window.minSize = NSSize(width: 440, height: 360)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        // 播放器全屏时也能在同一空间显示列表窗口。
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.contentViewController = contentViewController
        window.setAccessibilityIdentifier(AccessibilityID.Player.danmakuListWindow)
        window.setAccessibilityLabel(NSLocalizedString("弹幕列表", comment: ""))

        self.listViewController = contentViewController

        super.init(window: window)

        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 显示窗口；相对播放器窗口居中，并限制在当前屏幕可见范围内。
    func present(relativeTo parent: NSWindow?) {
        guard let window = self.window else { return }

        if let parent = parent, !parent.frame.isEmpty {
            var origin = NSPoint(
                x: parent.frame.midX - window.frame.width / 2,
                y: parent.frame.midY - window.frame.height / 2
            )
            if let screen = parent.screen ?? NSScreen.main {
                let visibleFrame = screen.visibleFrame
                origin.x = min(
                    max(origin.x, visibleFrame.minX + 8),
                    visibleFrame.maxX - window.frame.width - 8
                )
                origin.y = min(
                    max(origin.y, visibleFrame.minY + 8),
                    visibleFrame.maxY - window.frame.height - 8
                )
            }
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        self.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        self.onClose?()
        self.onClose = nil
    }
}
