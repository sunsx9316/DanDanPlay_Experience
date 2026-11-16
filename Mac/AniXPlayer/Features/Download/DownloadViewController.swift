//
//  DownloadViewController.swift
//  AniXPlayer
//
//  macOS：下载中心主界面。
//

import Cocoa
import SnapKit

private struct DownloadDetailFile {
    let path: String
    let sizeText: String
    let progress: Double?
    let isWanted: Bool?
    let canToggleWanted: Bool
    let fileIndex: Int?
    let priority: Int
    let canChangePriority: Bool

    var priorityDisplayName: String {
        switch priority {
        case 1:
            return NSLocalizedString("高", comment: "")
        case -1:
            return NSLocalizedString("低", comment: "")
        default:
            return NSLocalizedString("普通", comment: "")
        }
    }
}

final class DownloadViewController: ViewController {

    var onPlayFiles: (([File], File) -> Void)?

    private let manager: DownloadManager

    private let dropView = DownloadDropView()
    private var displayTasks: [DownloadTask] = []
    private var selectedTaskIDs: Set<UUID> = []
    private var detailFiles: [DownloadDetailFile] = []
    private var detailTaskID: UUID?
    private var isRestoringSelection = false
    private var btBannerHeight: NSLayoutConstraint?
    private var notificationToken: NSObjectProtocol?
    private var pendingPrefillSources: [String] = []
    private weak var activeAddSheet: DownloadAddSheetViewController?
    private var isPresentingAddSheet = false

    // MARK: Views

    private let titleLabel = DownloadViewController.makeLabel(
        NSLocalizedString("下载中心", comment: ""),
        font: .systemFont(ofSize: 22, weight: .bold),
        color: .labelColor
    )

    private let summaryLabel = DownloadViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 11.5),
        color: .secondaryLabelColor,
        alignment: .right
    )

    private lazy var addButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("添加…", comment: ""),
            target: self,
            action: #selector(addTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.Download.add)
        return button
    }()

    private lazy var startButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("开始", comment: ""),
            target: self,
            action: #selector(startTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.Download.start)
        return button
    }()

    private lazy var pauseButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("暂停", comment: ""),
            target: self,
            action: #selector(pauseTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.Download.pause)
        return button
    }()

    private lazy var stopButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("停止", comment: ""),
            target: self,
            action: #selector(stopTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.Download.stop)
        return button
    }()

    private lazy var deleteButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("删除", comment: ""),
            target: self,
            action: #selector(deleteTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.Download.delete)
        return button
    }()

    private lazy var refreshButton: NSButton = {
        let button = NSButton(
            image: NSImage.safeSystemSymbol("arrow.clockwise"),
            target: self,
            action: #selector(refreshTapped)
        )
        button.bezelStyle = .texturedRounded
        button.toolTip = NSLocalizedString("刷新", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.Download.refresh)
        return button
    }()

    private lazy var pasteButton: NSButton = {
        let button = NSButton(
            image: NSImage.safeSystemSymbol("doc.on.clipboard"),
            target: self,
            action: #selector(pasteFromClipboardTapped)
        )
        button.bezelStyle = .texturedRounded
        button.toolTip = NSLocalizedString("从剪贴板添加", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.Download.pasteFromClipboard)
        return button
    }()

    private lazy var pauseAllButton: NSButton = {
        let button = NSButton(
            image: NSImage.safeSystemSymbol("pause.fill"),
            target: self,
            action: #selector(pauseAllTapped)
        )
        button.bezelStyle = .texturedRounded
        button.toolTip = NSLocalizedString("全部暂停", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.Download.pauseAll)
        return button
    }()

    private lazy var resumeAllButton: NSButton = {
        let button = NSButton(
            image: NSImage.safeSystemSymbol("play.fill"),
            target: self,
            action: #selector(resumeAllTapped)
        )
        button.bezelStyle = .texturedRounded
        button.toolTip = NSLocalizedString("全部继续", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.Download.resumeAll)
        return button
    }()

    private lazy var settingsButton: NSButton = {
        let button = NSButton(
            image: NSImage.safeSystemSymbol("gearshape"),
            target: self,
            action: #selector(settingsTapped)
        )
        button.bezelStyle = .texturedRounded
        button.toolTip = NSLocalizedString("下载设置", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.Download.settings)
        return button
    }()

    private lazy var rssButton: NSButton = {
        let button = NSButton(
            image: NSImage.safeSystemSymbol("dot.radiowaves.left.and.right"),
            target: self,
            action: #selector(rssTapped)
        )
        button.bezelStyle = .texturedRounded
        button.toolTip = NSLocalizedString("RSS 订阅…", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.Download.rss)
        return button
    }()

    private lazy var searchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = NSLocalizedString("搜索任务…", comment: "")
        field.sendsSearchStringImmediately = false
        field.delegate = self
        field.setAccessibilityIdentifier(AccessibilityID.Download.search)
        return field
    }()

    private lazy var filterControl: NSSegmentedControl = {
        let control = NSSegmentedControl(
            labels: DownloadFilter.allCases.map { $0.displayName },
            trackingMode: .selectOne,
            target: self,
            action: #selector(filterChanged)
        )
        control.selectedSegment = 0
        control.setAccessibilityIdentifier(AccessibilityID.Download.filter)
        return control
    }()

    private lazy var sortPopup: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.addItems(withTitles: DownloadSort.allCases.map { $0.displayName })
        popup.target = self
        popup.action = #selector(sortChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.Download.sort)
        return popup
    }()

    private let btBanner = DownloadBTBannerView()

    private let tableContainer = NSView()
    private let tableView = NSTableView()
    private let tableScroll = NSScrollView()
    private let emptyStateView = DownloadEmptyStateView()

    private let detailContainer = NSView()
    private let detailTitleLabel = DownloadViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 13, weight: .semibold),
        color: .labelColor
    )
    private let detailStatusLabel = DownloadViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor
    )
    private let detailErrorLabel = DownloadViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .systemRed
    )
    private let detailFileTable = NSTableView()
    private let detailFileScroll = NSScrollView()
    private lazy var openFolderButton = NSButton(
        title: NSLocalizedString("在 Finder 中显示", comment: ""),
        target: self,
        action: #selector(openFolderTapped)
    )
    private lazy var playButton = NSButton(
        title: NSLocalizedString("播放", comment: ""),
        target: self,
        action: #selector(playTapped)
    )

    private let statusLabel = DownloadViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor
    )
    private let speedLabel = DownloadViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor,
        alignment: .right
    )

    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: NSLocalizedString("开始", comment: ""), action: #selector(startTapped), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("暂停", comment: ""), action: #selector(pauseTapped), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("停止", comment: ""), action: #selector(stopTapped), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("播放", comment: ""), action: #selector(playTapped), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("在 Finder 中显示", comment: ""), action: #selector(openFolderTapped), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("删除…", comment: ""), action: #selector(deleteTapped), keyEquivalent: "")
        for item in menu.items {
            item.target = self
        }
        return menu
    }()

    private lazy var detailFileContextMenu: NSMenu = {
        let menu = NSMenu()
        let priorityItem = NSMenuItem(
            title: NSLocalizedString("文件优先级", comment: ""),
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu()
        let priorities: [(TransmissionFilePriority, String)] = [
            (.high, AccessibilityID.Download.detailFilePriorityHigh),
            (.normal, AccessibilityID.Download.detailFilePriorityNormal),
            (.low, AccessibilityID.Download.detailFilePriorityLow),
        ]
        for (priority, identifier) in priorities {
            let item = NSMenuItem(
                title: priority.displayName,
                action: #selector(detailFilePriorityTapped(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = priority.rawValue
            item.identifier = NSUserInterfaceItemIdentifier(identifier)
            submenu.addItem(item)
        }
        priorityItem.submenu = submenu
        menu.addItem(priorityItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: NSLocalizedString("播放该文件", comment: ""),
            action: #selector(playDetailFileFromMenu),
            keyEquivalent: ""
        )
        menu.items.last?.target = self
        return menu
    }()

    // MARK: Init

    init(manager: DownloadManager = .shared) {
        self.manager = manager
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let notificationToken {
            NotificationCenter.default.removeObserver(notificationToken)
        }
    }

    // MARK: Lifecycle

    override func loadView() {
        dropView.frame = NSRect(x: 0, y: 0, width: 1000, height: 640)
        view = dropView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("下载中心", comment: "")
        view.setAccessibilityIdentifier(AccessibilityID.Download.root)
        dropView.onDropSources = { [weak self] sources in
            self?.acceptDroppedSources(sources)
        }

        setupLayout()
        setupTable()
        setupDetailTable()
        setupActions()

        notificationToken = NotificationCenter.default.addObserver(
            forName: DownloadManager.didChangeNotification,
            object: manager,
            queue: .main
        ) { [weak self] _ in
            self?.reloadData()
        }

        manager.bootstrap()
        reloadData()
        updateBTBanner()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        presentNextPrefillIfNeeded()
    }

    // MARK: Setup

    private func setupLayout() {
        view.addSubview(titleLabel)
        view.addSubview(summaryLabel)
        view.addSubview(addButton)
        view.addSubview(startButton)
        view.addSubview(pauseButton)
        view.addSubview(stopButton)
        view.addSubview(deleteButton)
        view.addSubview(refreshButton)
        view.addSubview(settingsButton)
        view.addSubview(pasteButton)
        view.addSubview(pauseAllButton)
        view.addSubview(resumeAllButton)
        view.addSubview(rssButton)
        view.addSubview(searchField)
        view.addSubview(filterControl)
        view.addSubview(sortPopup)
        view.addSubview(btBanner)
        view.addSubview(tableContainer)
        view.addSubview(detailContainer)
        view.addSubview(statusLabel)
        view.addSubview(speedLabel)

        tableContainer.addSubview(tableScroll)
        tableContainer.addSubview(emptyStateView)
        tableScroll.documentView = tableView

        emptyStateView.onAction = { [weak self] in self?.addTapped() }

        detailContainer.wantsLayer = true
        detailContainer.layer?.cornerRadius = 8
        detailContainer.layer?.cornerCurve = .continuous
        detailContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        detailContainer.addSubview(detailTitleLabel)
        detailContainer.addSubview(detailStatusLabel)
        detailContainer.addSubview(detailErrorLabel)
        detailContainer.addSubview(detailFileScroll)
        detailContainer.addSubview(openFolderButton)
        detailContainer.addSubview(playButton)
        detailFileScroll.documentView = detailFileTable

        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        summaryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.top.equalToSuperview().offset(16)
        }
        summaryLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-22)
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(12)
        }

        addButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
        }
        startButton.snp.makeConstraints { make in
            make.leading.equalTo(addButton.snp.trailing).offset(8)
            make.centerY.equalTo(addButton)
        }
        pauseButton.snp.makeConstraints { make in
            make.leading.equalTo(startButton.snp.trailing).offset(8)
            make.centerY.equalTo(addButton)
        }
        stopButton.snp.makeConstraints { make in
            make.leading.equalTo(pauseButton.snp.trailing).offset(8)
            make.centerY.equalTo(addButton)
        }
        deleteButton.snp.makeConstraints { make in
            make.leading.equalTo(stopButton.snp.trailing).offset(8)
            make.centerY.equalTo(addButton)
        }
        settingsButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-22)
            make.centerY.equalTo(addButton)
            make.width.height.equalTo(28)
        }
        refreshButton.snp.makeConstraints { make in
            make.trailing.equalTo(settingsButton.snp.leading).offset(-6)
            make.centerY.equalTo(addButton)
            make.width.height.equalTo(28)
        }
        pasteButton.snp.makeConstraints { make in
            make.trailing.equalTo(refreshButton.snp.leading).offset(-6)
            make.centerY.equalTo(addButton)
            make.width.height.equalTo(28)
        }
        pauseAllButton.snp.makeConstraints { make in
            make.trailing.equalTo(pasteButton.snp.leading).offset(-6)
            make.centerY.equalTo(addButton)
            make.width.height.equalTo(28)
        }
        resumeAllButton.snp.makeConstraints { make in
            make.trailing.equalTo(pauseAllButton.snp.leading).offset(-6)
            make.centerY.equalTo(addButton)
            make.width.height.equalTo(28)
        }
        rssButton.snp.makeConstraints { make in
            make.trailing.equalTo(resumeAllButton.snp.leading).offset(-6)
            make.centerY.equalTo(addButton)
            make.width.height.equalTo(28)
        }

        searchField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.top.equalTo(addButton.snp.bottom).offset(12)
            make.width.equalTo(220)
            make.height.equalTo(24)
        }
        filterControl.snp.makeConstraints { make in
            make.leading.equalTo(searchField.snp.trailing).offset(8)
            make.centerY.equalTo(searchField)
            make.width.equalTo(210)
        }
        sortPopup.snp.makeConstraints { make in
            make.leading.equalTo(filterControl.snp.trailing).offset(8)
            make.centerY.equalTo(searchField)
            make.width.equalTo(140)
        }

        btBanner.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.trailing.equalToSuperview().offset(-22)
            make.top.equalTo(searchField.snp.bottom).offset(10)
        }
        let bannerHeight = btBanner.heightAnchor.constraint(equalToConstant: 0)
        bannerHeight.isActive = true
        btBannerHeight = bannerHeight

        tableContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.trailing.equalToSuperview().offset(-22)
            make.top.equalTo(btBanner.snp.bottom).offset(8)
        }
        tableScroll.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }

        detailContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.trailing.equalToSuperview().offset(-22)
            make.top.equalTo(tableContainer.snp.bottom).offset(8)
            make.bottom.equalTo(statusLabel.snp.top).offset(-8)
            make.height.equalTo(178)
        }

        detailTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualTo(openFolderButton.snp.leading).offset(-8)
            make.top.equalToSuperview().offset(10)
        }
        detailStatusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalTo(detailTitleLabel.snp.bottom).offset(2)
        }
        detailErrorLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalTo(detailStatusLabel.snp.bottom).offset(2)
        }
        detailFileScroll.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalTo(detailErrorLabel.snp.bottom).offset(6)
            make.bottom.equalToSuperview().offset(-10)
        }
        openFolderButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalToSuperview().offset(8)
        }
        playButton.snp.makeConstraints { make in
            make.trailing.equalTo(openFolderButton.snp.leading).offset(-8)
            make.centerY.equalTo(openFolderButton)
        }
        openFolderButton.bezelStyle = .rounded
        openFolderButton.controlSize = .small
        openFolderButton.setAccessibilityIdentifier(AccessibilityID.Download.openFolder)
        playButton.bezelStyle = .rounded
        playButton.controlSize = .small
        playButton.setAccessibilityIdentifier(AccessibilityID.Download.play)

        statusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.bottom.equalToSuperview().offset(-8)
            make.trailing.lessThanOrEqualTo(speedLabel.snp.leading).offset(-12)
        }
        speedLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-22)
            make.centerY.equalTo(statusLabel)
            make.width.greaterThanOrEqualTo(180)
        }
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setAccessibilityIdentifier(AccessibilityID.Download.status)
    }

    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = .clear
        tableView.rowHeight = 38
        tableView.intercellSpacing = NSSize(width: 8, height: 2)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.setAccessibilityIdentifier(AccessibilityID.Download.table)
        tableView.target = self
        tableView.doubleAction = #selector(tableDoubleClicked)
        tableView.menu = contextMenu

        let columns: [(String, String, CGFloat)] = [
            ("title", NSLocalizedString("标题", comment: ""), 260),
            ("kind", NSLocalizedString("类型", comment: ""), 54),
            ("status", NSLocalizedString("状态", comment: ""), 76),
            ("progress", NSLocalizedString("进度", comment: ""), 140),
            ("speed", NSLocalizedString("速度", comment: ""), 110),
            ("eta", NSLocalizedString("剩余时间", comment: ""), 82),
            ("path", NSLocalizedString("保存路径", comment: ""), 210),
        ]
        for (identifier, title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.minWidth = min(width, 50)
            if identifier == "title" || identifier == "path" {
                column.resizingMask = [.autoresizingMask]
            }
            tableView.addTableColumn(column)
        }

        tableScroll.hasVerticalScroller = true
        tableScroll.hasHorizontalScroller = false
        tableScroll.autohidesScrollers = true
        tableScroll.drawsBackground = false
        tableScroll.borderType = .noBorder
    }

    private func setupDetailTable() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.title = NSLocalizedString("文件", comment: "")
        column.width = 600
        column.minWidth = 240
        column.resizingMask = [.autoresizingMask]
        detailFileTable.addTableColumn(column)
        detailFileTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        detailFileTable.headerView = nil
        detailFileTable.rowHeight = 24
        detailFileTable.dataSource = self
        detailFileTable.delegate = self
        detailFileTable.setAccessibilityIdentifier(AccessibilityID.Download.detailFiles)
        detailFileTable.target = self
        detailFileTable.doubleAction = #selector(detailFileDoubleClicked)
        detailFileTable.menu = detailFileContextMenu
        detailFileContextMenu.delegate = self

        detailFileScroll.hasVerticalScroller = true
        detailFileScroll.autohidesScrollers = true
        detailFileScroll.drawsBackground = false
        detailFileScroll.borderType = .noBorder
        detailFileScroll.documentView = detailFileTable

        detailTitleLabel.setAccessibilityIdentifier(AccessibilityID.Download.detailTitle)
        detailStatusLabel.setAccessibilityIdentifier(AccessibilityID.Download.detailStatus)
        detailErrorLabel.setAccessibilityIdentifier(AccessibilityID.Download.detailError)
        detailContainer.setAccessibilityIdentifier(AccessibilityID.Download.detailRoot)
        detailContainer.setAccessibilityElement(true)
        detailContainer.setAccessibilityRole(.group)
        detailErrorLabel.maximumNumberOfLines = 2
        detailStatusLabel.lineBreakMode = .byTruncatingMiddle
    }

    private func setupActions() {
        btBanner.onRetry = { [weak self] in
            self?.manager.checkBTAvailability()
        }
        btBanner.onSettings = { [weak self] in
            self?.settingsTapped()
        }
        btBanner.onDismiss = { [weak self] in
            guard let self else { return }
            self.manager.preferences.setBTOnboardingDismissed(true)
            self.updateBTBanner()
        }
        btBanner.onWebsite = {
            if let url = URL(string: "https://transmissionbt.com/") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: Data

    private func makeQuery() -> DownloadQuery {
        var query = DownloadQuery()
        query.searchText = searchField.stringValue
        let index = max(0, min(filterControl.selectedSegment, DownloadFilter.allCases.count - 1))
        query.filter = DownloadFilter.allCases[index]
        let sortIndex = max(0, min(sortPopup.indexOfSelectedItem, DownloadSort.allCases.count - 1))
        query.sort = DownloadSort.allCases[sortIndex]
        return query
    }

    private func reloadData() {
        let previousSelection = selectedTaskIDs
        displayTasks = DownloadQueryLogic.apply(manager.tasks, query: makeQuery())

        isRestoringSelection = true
        tableView.reloadData()
        tableView.deselectAll(nil)
        for (index, task) in displayTasks.enumerated() where previousSelection.contains(task.id) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: true)
        }
        isRestoringSelection = false
        selectedTaskIDs = Set(tableView.selectedRowIndexes.compactMap {
            $0 < displayTasks.count ? displayTasks[$0].id : nil
        })

        updateSummary()
        updateEmptyState()
        updateButtons()
        updateDetail()
        updateBTBanner()
    }

    private func updateSummary() {
        let active = manager.tasks.filter { $0.status == .downloading }.count
        let total = manager.tasks.count
        let speed = DownloadFormatting.speed(manager.totalDownloadSpeed)
        summaryLabel.stringValue = String(
            format: NSLocalizedString("共 %d 个任务 · 下载中 %d · %@", comment: ""),
            total,
            active,
            speed
        )

        if let error = manager.lastErrorMessage {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error
            statusLabel.toolTip = error
        } else if let notice = manager.lastNoticeMessage {
            statusLabel.textColor = .controlAccentColor
            statusLabel.stringValue = notice
            statusLabel.toolTip = notice
        } else if !manager.preferences.enableBT {
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = NSLocalizedString("BT 集成已关闭，仅支持 HTTP/HTTPS 下载", comment: "")
            statusLabel.toolTip = nil
        } else if !manager.btState.isAvailable, !manager.tasks.isEmpty {
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = manager.btState.displayText
            statusLabel.toolTip = manager.btState.displayText
        } else {
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = manager.storeError?.localizedDescription
                ?? NSLocalizedString("下载任务会自动保存，关闭窗口后仍会在后台继续。", comment: "")
            statusLabel.toolTip = nil
        }

        speedLabel.stringValue = String(
            format: NSLocalizedString("↓ %@ · ↑ %@", comment: ""),
            DownloadFormatting.speed(manager.totalDownloadSpeed),
            DownloadFormatting.speed(manager.totalUploadSpeed)
        )
    }

    private func updateEmptyState() {
        if let error = manager.storeError, manager.tasks.isEmpty {
            emptyStateView.configure(
                symbolName: "exclamationmark.triangle",
                title: NSLocalizedString("下载中心无法打开", comment: ""),
                detail: error.localizedDescription,
                actionTitle: NSLocalizedString("重试", comment: ""),
                onAction: { [weak self] in self?.manager.reloadStore() }
            )
            emptyStateView.isHidden = false
            tableScroll.isHidden = true
            return
        }

        let query = makeQuery()
        let isFiltering = !query.trimmedSearchText.isEmpty || query.filter != .all
        let show: Bool
        if manager.tasks.isEmpty {
            let detail: String
            if manager.preferences.enableBT, !manager.btState.isAvailable {
                detail = NSLocalizedString(
                    "可以添加 HTTP/HTTPS 直链；磁力/种子需要先配置 Transmission RPC（见上方提示或下载设置）。",
                    comment: ""
                )
            } else {
                detail = NSLocalizedString("添加磁力链接、.torrent 种子或 HTTP/HTTPS 直链开始下载。也可以把链接或种子文件拖到窗口里。", comment: "")
            }
            emptyStateView.configure(
                symbolName: "arrow.down.circle",
                title: NSLocalizedString("还没有下载任务", comment: ""),
                detail: detail,
                actionTitle: NSLocalizedString("添加下载…", comment: ""),
                onAction: { [weak self] in self?.addTapped() }
            )
            show = true
        } else if displayTasks.isEmpty {
            emptyStateView.configure(
                symbolName: isFiltering ? "line.3.horizontal.decrease.circle" : "tray",
                title: NSLocalizedString("没有符合条件的任务", comment: ""),
                detail: NSLocalizedString("尝试清空搜索词或切换筛选条件。", comment: ""),
                actionTitle: nil,
                onAction: nil
            )
            show = true
        } else {
            show = false
        }

        emptyStateView.isHidden = !show
        tableScroll.isHidden = show
    }

    private func updateButtons() {
        let selected = selectedTasks()
        let isEnabled = !selected.isEmpty

        startButton.isEnabled = isEnabled && selected.contains { $0.status.canStart }
        pauseButton.isEnabled = isEnabled && selected.contains { $0.status.canPause }
        stopButton.isEnabled = isEnabled && selected.contains { $0.status.canStop }
        deleteButton.isEnabled = isEnabled
        pauseAllButton.isEnabled = manager.tasks.contains { $0.status.canPause }
        resumeAllButton.isEnabled = manager.tasks.contains { $0.status.canStart }

        let single = selected.count == 1 ? selected[0] : nil
        openFolderButton.isEnabled = single != nil
        playButton.isEnabled = selected.contains { task in
            !manager.completedPlaybackURLs(for: task).isEmpty
                || manager.streamingPlaybackURL(for: task) != nil
        }

        if let task = single {
            let playableCount = manager.completedPlaybackURLs(for: task).count
            if playableCount > 1 {
                playButton.title = NSLocalizedString("播放全部", comment: "")
            } else if playableCount == 1 {
                playButton.title = NSLocalizedString("播放", comment: "")
            } else if manager.streamingPlaybackURL(for: task) != nil {
                playButton.title = NSLocalizedString("播放已下载部分", comment: "")
            } else {
                playButton.title = NSLocalizedString("播放", comment: "")
            }
        } else {
            playButton.title = NSLocalizedString("播放", comment: "")
        }
    }

    private func updateDetail() {
        let selected = selectedTasks()
        guard let task = selected.first else {
            detailTaskID = nil
            detailTitleLabel.stringValue = NSLocalizedString("选择一个任务查看详情", comment: "")
            detailStatusLabel.stringValue = ""
            detailErrorLabel.stringValue = ""
            detailErrorLabel.isHidden = true
            detailFiles = []
            detailFileTable.reloadData()
            return
        }

        detailTitleLabel.stringValue = task.displayTitle
        detailTitleLabel.toolTip = task.source
        detailTaskID = task.id
        let missingFiles = manager.hasMissingFiles(for: task)
        detailStatusLabel.stringValue = String(
            format: NSLocalizedString("%@ · %@ · %@ · 保存到 %@", comment: ""),
            task.kind.displayName,
            missingFiles ? NSLocalizedString("已完成（文件缺失）", comment: "") : task.status.displayName,
            DownloadFormatting.bytesProgress(
                downloaded: task.downloadedBytes,
                total: task.totalBytes
            ),
            task.savePath
        )
        detailStatusLabel.toolTip = task.savePath

        if missingFiles {
            detailErrorLabel.textColor = .systemOrange
            detailErrorLabel.stringValue = NSLocalizedString(
                "下载文件已被移动或删除，无法播放。可在 Finder 中查找或重新下载。",
                comment: ""
            )
            detailErrorLabel.isHidden = false
        } else if task.status == .completed, !task.filePaths.isEmpty,
                  manager.completedPlaybackURLs(for: task).isEmpty {
            detailErrorLabel.textColor = .systemOrange
            detailErrorLabel.stringValue = NSLocalizedString(
                "已完成，但没有找到可播放的视频文件。",
                comment: ""
            )
            detailErrorLabel.isHidden = false
        } else if let error = task.errorMessage, !error.isEmpty {
            detailErrorLabel.textColor = .systemRed
            detailErrorLabel.stringValue = error
            detailErrorLabel.toolTip = error
            detailErrorLabel.isHidden = false
        } else {
            detailErrorLabel.stringValue = ""
            detailErrorLabel.isHidden = true
        }

        let canToggle = manager.canSelectFiles(for: task)
        let canChangePriority = manager.canChangeFilePriority(for: task)
        var progressByPath: [String: DownloadFileProgress] = [:]
        for file in manager.files(for: task) {
            progressByPath[file.path] = file
        }
        detailFiles = task.filePaths.map { path in
            let live = progressByPath[path]
            let localPath = manager.localPath(for: path, task: task)
            let size = live?.length ?? DownloadFileRules.existingFileSize(at: localPath) ?? 0
            let sizeText: String
            if let live, live.length > 0 {
                sizeText = DownloadFormatting.bytesProgress(
                    downloaded: live.completedBytes,
                    total: live.length
                )
            } else {
                sizeText = size > 0 ? DownloadFormatting.byteCount(size) : "—"
            }
            return DownloadDetailFile(
                path: path,
                sizeText: sizeText,
                progress: live?.progress,
                isWanted: live?.isWanted,
                canToggleWanted: canToggle && (live != nil),
                fileIndex: live?.index,
                priority: live?.priority ?? 0,
                canChangePriority: canChangePriority && (live != nil)
            )
        }
        detailFiles.sort {
            if let left = $0.fileIndex, let right = $1.fileIndex {
                return left < right
            }
            return $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
        detailFileTable.reloadData()
    }

    private func updateBTBanner() {
        let visible: Bool
        if !manager.preferences.enableBT || manager.preferences.btOnboardingDismissed {
            btBanner.configure(
                title: "",
                detail: "",
                isChecking: false,
                showRetry: false,
                showInstallHelp: false,
                showSettings: false
            )
            visible = false
        } else {
            switch manager.btState {
            case .available:
                btBanner.configure(
                    title: "",
                    detail: "",
                    isChecking: false,
                    showRetry: false,
                    showInstallHelp: false,
                    showSettings: false
                )
                visible = false
            case .checking:
                btBanner.configure(
                    title: NSLocalizedString("正在检测 BT 内核…", comment: ""),
                    detail: NSLocalizedString("正在连接 Transmission RPC，磁力/种子任务稍后可用。", comment: ""),
                    isChecking: true,
                    showRetry: false,
                    showInstallHelp: false,
                    showSettings: true
                )
                visible = true
            case .unknown:
                btBanner.configure(
                    title: NSLocalizedString("BT 内核尚未检测", comment: ""),
                    detail: NSLocalizedString("磁力/种子需要本机 transmission-daemon；点击重试检测，或在下载设置中配置 RPC。", comment: ""),
                    isChecking: false,
                    showRetry: true,
                    showInstallHelp: true,
                    showSettings: true
                )
                visible = true
            case .unavailable(let message):
                btBanner.configure(
                    title: NSLocalizedString("未检测到可用的 BT 内核", comment: ""),
                    detail: String(
                        format: NSLocalizedString("%@ 安装：%@，启动 transmission-daemon 后重试。", comment: ""),
                        message,
                        "brew install transmission"
                    ),
                    isChecking: false,
                    showRetry: true,
                    showInstallHelp: true,
                    showSettings: true
                )
                visible = true
            case .error(let message):
                btBanner.configure(
                    title: NSLocalizedString("BT 内核连接异常", comment: ""),
                    detail: message,
                    isChecking: false,
                    showRetry: true,
                    showInstallHelp: true,
                    showSettings: true
                )
                visible = true
            }
        }

        btBanner.isHidden = !visible
        btBannerHeight?.constant = visible ? 92 : 0
    }

    // MARK: Selection

    private func selectedTasks() -> [DownloadTask] {
        displayTasks.filter { selectedTaskIDs.contains($0.id) }
    }

    private func selectClickedRowIfNeeded() {
        let row = tableView.clickedRow
        guard row >= 0, row < displayTasks.count else { return }
        if !selectedTaskIDs.contains(displayTasks[row].id) {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            selectedTaskIDs = [displayTasks[row].id]
            updateButtons()
            updateDetail()
        }
    }

    // MARK: Actions

    @objc private func addTapped() {
        presentAddSheet(prefillSource: nil)
    }

    /// 系统入口/通知/剪贴板共用：复用下载窗口并预填添加 sheet。
    func openAddSheet(prefillSource: String?) {
        if let prefillSource, !prefillSource.isEmpty {
            pendingPrefillSources.removeAll { $0 == prefillSource }
            pendingPrefillSources.insert(prefillSource, at: 0)
        }
        presentNextPrefillIfNeeded()
    }

    func enqueuePrefillSources(_ sources: [String]) {
        let cleaned = sources
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        for source in cleaned where !pendingPrefillSources.contains(source) {
            pendingPrefillSources.append(source)
        }
        presentNextPrefillIfNeeded()
    }

    private func presentNextPrefillIfNeeded() {
        guard !pendingPrefillSources.isEmpty else { return }
        guard isViewLoaded, view.window != nil else { return }

        if isPresentingAddSheet {
            if let sheet = activeAddSheet, let next = pendingPrefillSources.first {
                pendingPrefillSources.removeFirst()
                sheet.replacePrefillSource(next)
            }
            return
        }

        let prefill = pendingPrefillSources.removeFirst()
        presentAddSheet(prefillSource: prefill)
    }

    private func presentAddSheet(prefillSource: String?) {
        guard !isPresentingAddSheet else {
            if let prefillSource, let sheet = activeAddSheet {
                sheet.replacePrefillSource(prefillSource)
            }
            return
        }
        guard view.window != nil else {
            if let prefillSource { pendingPrefillSources.insert(prefillSource, at: 0) }
            return
        }

        let directory = (try? manager.preferences.ensureDefaultSaveDirectory())
            ?? manager.preferences.defaultSaveDirectoryURL
        let sheet = DownloadAddSheetViewController(
            defaultSavePath: directory.path,
            defaultBookmark: manager.preferences.defaultSaveBookmark,
            prefillSource: prefillSource ?? ""
        )
        sheet.onSubmit = { [weak self] source, savePath, bookmark, completion in
            guard let self else { return }
            self.manager.add(
                rawSource: source,
                savePath: savePath,
                bookmark: bookmark
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let addResult):
                        self.revealTask(id: addResult.task.id)
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
        sheet.onOpenBTSettings = { [weak self] in
            self?.settingsTapped()
        }
        sheet.onCancel = { [weak self] in
            self?.pendingPrefillSources.removeAll()
        }
        sheet.onDismiss = { [weak self] in
            guard let self else { return }
            self.activeAddSheet = nil
            self.isPresentingAddSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.presentNextPrefillIfNeeded()
            }
        }

        activeAddSheet = sheet
        isPresentingAddSheet = true
        presentAsSheet(sheet)
    }

    func revealTask(id: UUID) {
        guard isViewLoaded else { return }
        searchField.stringValue = ""
        filterControl.selectedSegment = 0
        reloadData()
        guard let index = displayTasks.firstIndex(where: { $0.id == id }) else { return }
        selectedTaskIDs = [id]
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
        updateButtons()
        updateDetail()
    }

    @objc private func pasteFromClipboardTapped() {
        let pasteboard = NSPasteboard.general
        var rawSources: [String] = []
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            rawSources.append(string)
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            rawSources.append(contentsOf: urls.map { $0.path })
        }
        let sources = rawSources.compactMap { prepareDownloadSource(from: $0) }
        guard !sources.isEmpty else {
            showAlert(
                title: NSLocalizedString("剪贴板中没有下载链接", comment: ""),
                message: NSLocalizedString("请复制磁力链接、.torrent 文件或 HTTP/HTTPS 直链后重试。", comment: "")
            )
            return
        }
        enqueuePrefillSources(sources)
    }

    private func acceptDroppedSources(_ rawSources: [String]) {
        let sources = rawSources.compactMap { prepareDownloadSource(from: $0) }
        guard !sources.isEmpty else {
            NSSound.beep()
            showAlert(
                title: NSLocalizedString("无法识别拖入的内容", comment: ""),
                message: NSLocalizedString("支持磁力链接、.torrent 种子文件或 HTTP/HTTPS 直链。", comment: "")
            )
            return
        }
        enqueuePrefillSources(sources)
    }

    /// 校验链接；本地 .torrent 先复制到 App 目录，避免沙盒临时授权失效。
    private func prepareDownloadSource(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let torrentPath = DownloadTorrentImporter.torrentPath(from: trimmed) {
            do {
                return try DownloadTorrentImporter.importTorrent(
                    at: URL(fileURLWithPath: torrentPath)
                )
            } catch {
                showAlert(
                    title: NSLocalizedString("无法读取种子文件", comment: ""),
                    message: error.localizedDescription
                )
                return nil
            }
        }

        do {
            return try DownloadSourceParser.parse(trimmed).source
        } catch {
            return nil
        }
    }

    @objc private func startTapped() {
        manager.start(ids: selectedTasks().map { $0.id })
    }

    @objc private func pauseTapped() {
        manager.pause(ids: selectedTasks().map { $0.id })
    }

    @objc private func stopTapped() {
        manager.stop(ids: selectedTasks().map { $0.id })
    }

    @objc private func pauseAllTapped() {
        manager.pauseAll()
    }

    @objc private func resumeAllTapped() {
        manager.resumeAll()
    }

    @objc private func deleteTapped() {
        selectClickedRowIfNeeded()
        let tasks = selectedTasks()
        guard !tasks.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = tasks.count == 1
            ? String(format: NSLocalizedString("删除「%@」？", comment: ""), tasks[0].displayTitle)
            : String(format: NSLocalizedString("删除 %d 个下载任务？", comment: ""), tasks.count)
        alert.informativeText = NSLocalizedString("可以选择同时删除已经下载到磁盘的文件。", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("仅移除任务", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("移除并删除文件", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self else { return }
            let ids = tasks.map { $0.id }
            switch response {
            case .alertFirstButtonReturn:
                self.manager.remove(ids: ids, deleteFiles: false)
            case .alertSecondButtonReturn:
                self.manager.remove(ids: ids, deleteFiles: true)
            default:
                break
            }
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    @objc private func refreshTapped() {
        manager.reloadStore()
        manager.refreshNow()
        if manager.preferences.enableBT, !manager.btState.isAvailable {
            manager.checkBTAvailability()
        }
    }

    @objc private func rssTapped() {
        let sheet = DownloadRSSSheetViewController(manager: manager)
        presentAsSheet(sheet)
    }

    private func presentLimitsSheet() {
        let sheet = DownloadLimitsSheetViewController(manager: manager)
        sheet.onSaved = { [weak self] in
            self?.reloadData()
        }
        presentAsSheet(sheet)
    }

    @objc private func settingsTapped() {
        let sheet = DownloadSettingsSheetViewController(preferences: manager.preferences)
        sheet.onOpenAdvanced = { [weak self] in
            self?.presentLimitsSheet()
        }
        sheet.onSave = { [weak self] draft in
            guard let self else { return }
            let access = DownloadFileAccess.resolveDirectory(
                path: draft.savePath,
                bookmark: draft.saveBookmark
            )
            do {
                try FileManager.default.createDirectory(
                    at: access.url,
                    withIntermediateDirectories: true
                )
            } catch {
                access.securityScopedURL?.stopAccessingSecurityScopedResource()
                throw error
            }
            access.securityScopedURL?.stopAccessingSecurityScopedResource()

            self.manager.preferences.setDefaultSaveDirectory(
                URL(fileURLWithPath: draft.savePath, isDirectory: true),
                bookmark: draft.saveBookmark
            )
            try self.manager.preferences.updateRPC(
                host: draft.host,
                port: draft.port,
                useHTTPS: draft.useHTTPS,
                username: draft.username,
                password: draft.password,
                sequentialDownload: draft.sequentialDownload,
                enableBT: draft.enableBT,
                maxConcurrentDownloads: draft.maxConcurrentDownloads
            )
            self.manager.preferences.setNotificationsEnabled(draft.notificationsEnabled)
            if draft.notificationsEnabled {
                DownloadNotifier.shared.requestAuthorizationIfNeeded(
                    preferences: self.manager.preferences
                )
            }
            if draft.resetBTOnboarding {
                self.manager.preferences.setBTOnboardingDismissed(false)
            }
            self.manager.reloadSettings()
        }
        presentAsSheet(sheet)
    }

    @objc private func filterChanged() {
        reloadData()
    }

    @objc private func sortChanged() {
        reloadData()
    }

    @objc private func tableDoubleClicked() {
        guard tableView.clickedRow >= 0 else { return }
        selectClickedRowIfNeeded()
        playTapped()
    }

    @objc private func detailFileDoubleClicked() {
        let row = detailFileTable.clickedRow
        guard row >= 0, row < detailFiles.count else { return }
        playFile(at: detailFiles[row].path)
    }

    @objc private func playDetailFileFromMenu() {
        let row = detailFileTable.clickedRow >= 0
            ? detailFileTable.clickedRow
            : detailFileTable.selectedRow
        guard row >= 0, row < detailFiles.count else { return }
        playFile(at: detailFiles[row].path)
    }

    @objc private func detailFilePriorityTapped(_ sender: NSMenuItem) {
        let row = detailFileTable.clickedRow >= 0
            ? detailFileTable.clickedRow
            : detailFileTable.selectedRow
        guard row >= 0, row < detailFiles.count,
              let rawPriority = sender.representedObject as? Int,
              let priority = TransmissionFilePriority(rawValue: rawPriority),
              let taskID = detailTaskID else {
            return
        }
        let file = detailFiles[row]
        guard file.canChangePriority else { return }
        manager.setFilePriority(taskID: taskID, path: file.path, priority: priority)
    }

    @objc private func openFolderTapped() {
        selectClickedRowIfNeeded()
        guard let task = selectedTasks().first else { return }

        let existingFile = manager.localFilePaths(for: task).first {
            FileManager.default.fileExists(atPath: $0)
        }
        if let existingFile {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: existingFile)])
            return
        }

        let localSavePath = manager.localSavePath(for: task)
        let directory = URL(fileURLWithPath: localSavePath, isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) {
            NSWorkspace.shared.open(directory)
        } else {
            showAlert(
                title: NSLocalizedString("目录不存在", comment: ""),
                message: localSavePath
            )
        }
    }

    @objc private func playTapped() {
        selectClickedRowIfNeeded()
        let tasks = selectedTasks()
        guard !tasks.isEmpty else { return }

        let completedURLs = tasks.flatMap { manager.completedPlaybackURLs(for: $0) }
        if !completedURLs.isEmpty {
            startPlayback(urls: completedURLs)
            return
        }

        if tasks.count == 1, manager.hasMissingFiles(for: tasks[0]) {
            showAlert(
                title: NSLocalizedString("文件缺失", comment: ""),
                message: NSLocalizedString("下载文件已被移动或删除，无法播放。可在 Finder 中查找或重新下载。", comment: "")
            )
            return
        }

        if tasks.allSatisfy({ $0.status == .completed }) {
            showAlert(
                title: NSLocalizedString("没有可播放文件", comment: ""),
                message: NSLocalizedString("已完成的任务中没有找到可播放的视频文件。", comment: "")
            )
            return
        }

        guard tasks.count == 1 else {
            showAlert(
                title: NSLocalizedString("暂不可播放", comment: ""),
                message: NSLocalizedString("下载完成后即可播放。", comment: "")
            )
            return
        }
        let task = tasks[0]

        if let streamURL = manager.streamingPlaybackURL(for: task) {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("任务尚未下载完成", comment: "")
            alert.informativeText = NSLocalizedString(
                "将尝试播放已下载的部分，播放器可能无法读取完整内容。下载完成后播放效果最佳。",
                comment: ""
            )
            alert.alertStyle = .informational
            alert.addButton(withTitle: NSLocalizedString("播放已下载部分", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))
            let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                self?.startPlayback(urls: [streamURL])
            }
            if let window = view.window {
                alert.beginSheetModal(for: window, completionHandler: handle)
            } else {
                handle(alert.runModal())
            }
            return
        }

        let message: String
        if task.kind == .http {
            message = NSLocalizedString("HTTP 下载需要完成后才能播放。", comment: "")
        } else {
            message = NSLocalizedString("下载完成后播放。BT 任务需要 sequential 下载且文件达到 20MB 后才可尝试边下边播。", comment: "")
        }
        showAlert(title: NSLocalizedString("暂不可播放", comment: ""), message: message)
    }

    private func startPlayback(urls: [URL]) {
        var seen = Set<String>()
        let files = urls
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .filter { seen.insert($0.standardizedFileURL.path).inserted }
            .map { LocalFile(with: $0) }
        guard let first = files.first else {
            showAlert(
                title: NSLocalizedString("文件不可用", comment: ""),
                message: NSLocalizedString("下载文件不存在或已被移动。", comment: "")
            )
            return
        }
        onPlayFiles?(files, first)
    }

    private func playFile(at path: String) {
        let localPath = detailTaskID.map { manager.localPath(for: path, taskID: $0) } ?? path
        guard FileManager.default.fileExists(atPath: localPath) else {
            showAlert(
                title: NSLocalizedString("文件不存在", comment: ""),
                message: localPath
            )
            return
        }
        let file = LocalFile(with: URL(fileURLWithPath: localPath))
        onPlayFiles?([file], file)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("好", comment: ""))
        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    // MARK: Helpers

    fileprivate static func makeLabel(
        _ text: String,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment = .left
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.alignment = alignment
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private func text(for column: String, task: DownloadTask) -> String {
        switch column {
        case "kind":
            return task.kind.displayName
        case "status":
            if manager.hasMissingFiles(for: task) {
                return NSLocalizedString("已完成（文件缺失）", comment: "")
            }
            return task.status.displayName
        case "speed":
            let download = DownloadFormatting.speed(task.downloadSpeed)
            if task.uploadSpeed > 0 {
                return "↓ \(download) ↑ \(DownloadFormatting.speed(task.uploadSpeed))"
            }
            return download
        case "eta":
            return task.status == .completed ? "—" : DownloadFormatting.eta(task.etaSeconds)
        case "path":
            return task.savePath
        default:
            return task.displayTitle
        }
    }
}

// MARK: - Search field

extension DownloadViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        reloadData()
    }
}

// MARK: - Main table

extension DownloadViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === self.tableView ? displayTasks.count : detailFiles.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        if tableView === detailFileTable {
            guard row < detailFiles.count else { return nil }
            return detailFileCell(for: detailFiles[row], in: detailFileTable)
        }

        guard row < displayTasks.count, let tableColumn else { return nil }
        let task = displayTasks[row]
        let identifier = tableColumn.identifier.rawValue

        if identifier == "progress" {
            return progressCell(for: task)
        }

        let cell = textCell(column: identifier)
        cell.textField?.stringValue = text(for: identifier, task: task)
        cell.textField?.textColor = .labelColor

        if identifier == "status" {
            if manager.hasMissingFiles(for: task) {
                cell.textField?.textColor = .systemOrange
            } else {
                switch task.status {
                case .failed:
                    cell.textField?.textColor = .systemRed
                case .completed:
                    cell.textField?.textColor = .systemGreen
                case .downloading:
                    cell.textField?.textColor = .controlAccentColor
                default:
                    cell.textField?.textColor = .secondaryLabelColor
                }
            }
        }
        if identifier == "title" {
            cell.textField?.toolTip = task.source
        }
        if identifier == "status" {
            cell.textField?.toolTip = task.errorMessage?.isEmpty == false
                ? task.errorMessage
                : nil
        }
        if identifier == "path" {
            cell.textField?.lineBreakMode = .byTruncatingMiddle
            cell.textField?.toolTip = task.savePath
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isRestoringSelection else { return }
        guard let table = notification.object as? NSTableView, table === tableView else { return }
        selectedTaskIDs = Set(tableView.selectedRowIndexes.compactMap {
            $0 < displayTasks.count ? displayTasks[$0].id : nil
        })
        updateButtons()
        updateDetail()
    }

    private func textCell(column: String) -> NSTableCellView {
        let identifier = NSUserInterfaceItemIdentifier("download.cell.\(column)")
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            return reused
        }
        let cell = NSTableCellView()
        cell.identifier = identifier
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.lineBreakMode = .byTruncatingTail
        cell.textField = label
        cell.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(2)
            make.centerY.equalToSuperview()
        }
        return cell
    }

    private func progressCell(for task: DownloadTask) -> NSView {
        let identifier = NSUserInterfaceItemIdentifier("download.cell.progress")
        let cell: DownloadProgressCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? DownloadProgressCellView {
            cell = reused
        } else {
            cell = DownloadProgressCellView()
            cell.identifier = identifier
        }
        cell.configure(progress: task.normalizedProgress, status: task.status)
        return cell
    }

    private func detailFileCell(for file: DownloadDetailFile, in table: NSTableView) -> NSView {
        let identifier = NSUserInterfaceItemIdentifier("download.cell.file")
        let cell: DownloadFileCellView
        if let reused = table.makeView(withIdentifier: identifier, owner: self) as? DownloadFileCellView {
            cell = reused
        } else {
            cell = DownloadFileCellView()
            cell.identifier = identifier
        }

        let name = (file.path as NSString).lastPathComponent
        let localPath = detailTaskID.map {
            manager.localPath(for: file.path, taskID: $0)
        } ?? file.path
        let exists = DownloadFileRules.existingFileSize(at: localPath) != nil
        let priorityPrefix = file.fileIndex == nil
            ? ""
            : "\(file.priorityDisplayName) · "
        let detailText: String
        if let progress = file.progress {
            detailText = "\(priorityPrefix)\(DownloadFormatting.percent(progress)) · \(file.sizeText)"
        } else {
            detailText = "\(priorityPrefix)\(file.sizeText)"
        }
        cell.configure(
            name: name,
            detail: detailText,
            path: file.path,
            checkboxVisible: file.canToggleWanted,
            checked: file.isWanted ?? true,
            textColor: exists ? .labelColor : .tertiaryLabelColor,
            accessibilityIdentifier: file.fileIndex.map {
                AccessibilityID.Download.detailFileTogglePrefix + "\($0)"
            }
        )
        cell.onToggle = { [weak self] wanted in
            guard let self, let taskID = self.detailTaskID else { return }
            self.manager.setFileWanted(taskID: taskID, path: file.path, wanted: wanted)
        }
        return cell
    }
}

// MARK: - Context menu

extension DownloadViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === detailFileContextMenu {
            let row = detailFileTable.clickedRow >= 0
                ? detailFileTable.clickedRow
                : detailFileTable.selectedRow
            let file = row >= 0 && row < detailFiles.count ? detailFiles[row] : nil
            for item in menu.items {
                if item.submenu != nil {
                    item.isEnabled = file?.canChangePriority == true
                    item.submenu?.items.forEach {
                        $0.isEnabled = file?.canChangePriority == true
                    }
                } else if !item.isSeparatorItem {
                    item.isEnabled = file != nil
                }
            }
            return
        }

        let tasks = selectedTasks()
        let hasSelection = !tasks.isEmpty
        for item in menu.items where !item.isSeparatorItem {
            switch item.action {
            case #selector(startTapped):
                item.isEnabled = hasSelection && tasks.contains { $0.status.canStart }
            case #selector(pauseTapped):
                item.isEnabled = hasSelection && tasks.contains { $0.status.canPause }
            case #selector(stopTapped):
                item.isEnabled = hasSelection && tasks.contains { $0.status.canStop }
            case #selector(playTapped):
                item.isEnabled = tasks.contains {
                    !manager.completedPlaybackURLs(for: $0).isEmpty
                        || manager.streamingPlaybackURL(for: $0) != nil
                }
            case #selector(openFolderTapped):
                item.isEnabled = hasSelection
            case #selector(deleteTapped):
                item.isEnabled = hasSelection
            default:
                break
            }
        }
    }
}

// MARK: - Progress cell

private final class DownloadProgressCellView: NSTableCellView {

    private let bar = NSProgressIndicator()
    private let percentLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        bar.style = .bar
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 1
        bar.controlSize = .small

        percentLabel.font = .systemFont(ofSize: 10.5)
        percentLabel.textColor = .secondaryLabelColor
        percentLabel.alignment = .right

        addSubview(bar)
        addSubview(percentLabel)
        percentLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-2)
            make.centerY.equalToSuperview()
            make.width.equalTo(42)
        }
        bar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(2)
            make.trailing.equalTo(percentLabel.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
            make.height.equalTo(6)
        }
    }

    func configure(progress: Double, status: DownloadTaskStatus) {
        bar.doubleValue = progress
        percentLabel.stringValue = DownloadFormatting.percent(progress)
        bar.isHidden = false
        if status == .completed {
            percentLabel.textColor = .systemGreen
        } else {
            percentLabel.textColor = .secondaryLabelColor
        }
    }
}

// MARK: - File cell

private final class DownloadFileCellView: NSTableCellView {

    var onToggle: ((Bool) -> Void)?

    private let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fileIcon = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        checkbox.controlSize = .small
        checkbox.target = self
        checkbox.action = #selector(checkboxToggled)

        fileIcon.image = NSImage.safeSystemSymbol("doc")
        fileIcon.contentTintColor = .tertiaryLabelColor
        fileIcon.imageScaling = .scaleProportionallyDown

        nameLabel.font = .systemFont(ofSize: 11.5)
        nameLabel.lineBreakMode = .byTruncatingMiddle

        detailLabel.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .right
        detailLabel.lineBreakMode = .byTruncatingTail

        addSubview(checkbox)
        addSubview(fileIcon)
        addSubview(nameLabel)
        addSubview(detailLabel)

        checkbox.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(2)
            make.centerY.equalToSuperview()
            make.width.equalTo(16)
        }
        fileIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(2)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalTo(detailLabel.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        detailLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
            make.width.equalTo(190)
        }
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    func configure(
        name: String,
        detail: String,
        path: String,
        checkboxVisible: Bool,
        checked: Bool,
        textColor: NSColor,
        accessibilityIdentifier: String?
    ) {
        nameLabel.stringValue = name
        nameLabel.toolTip = path
        nameLabel.textColor = textColor
        detailLabel.stringValue = detail
        detailLabel.toolTip = detail
        checkbox.state = checked ? .on : .off
        checkbox.isHidden = !checkboxVisible
        fileIcon.isHidden = checkboxVisible
        checkbox.setAccessibilityIdentifier(accessibilityIdentifier ?? "")
    }

    @objc private func checkboxToggled() {
        onToggle?(checkbox.state == .on)
    }
}

// MARK: - BT banner

private final class DownloadBTBannerView: NSView {

    var onRetry: (() -> Void)?
    var onSettings: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onWebsite: (() -> Void)?

    private let iconView = ImageView()
    private let spinner = NSProgressIndicator()
    private let titleLabel = DownloadViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 12, weight: .semibold),
        color: .labelColor
    )
    private let detailLabel = DownloadViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 10.5),
        color: .secondaryLabelColor
    )
    private let retryButton = NSButton(title: "", target: nil, action: nil)
    private let copyButton = NSButton(title: "", target: nil, action: nil)
    private let websiteButton = NSButton(title: "", target: nil, action: nil)
    private let settingsButton = NSButton(title: "", target: nil, action: nil)
    private let dismissButton = NSButton(title: "", target: nil, action: nil)
    private let buttonStack = NSStackView()

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
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.10).cgColor

        setAccessibilityElement(true)
        setAccessibilityRole(.group)

        iconView.image = NSImage.safeSystemSymbol("exclamationmark.triangle.fill")
        iconView.contentTintColor = .systemOrange
        iconView.setScaling(.aspectFit)
        iconView.setAccessibilityElement(false)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.setAccessibilityIdentifier(AccessibilityID.Download.btSpinner)

        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 2

        configureButton(
            retryButton,
            title: NSLocalizedString("重试检测", comment: ""),
            action: #selector(retryTapped),
            identifier: AccessibilityID.Download.btRetry
        )
        configureButton(
            copyButton,
            title: NSLocalizedString("复制安装命令", comment: ""),
            action: #selector(copyTapped),
            identifier: AccessibilityID.Download.btCopyCommand
        )
        configureButton(
            websiteButton,
            title: NSLocalizedString("Transmission 官网", comment: ""),
            action: #selector(websiteTapped),
            identifier: AccessibilityID.Download.btWebsite
        )
        configureButton(
            settingsButton,
            title: NSLocalizedString("RPC 设置…", comment: ""),
            action: #selector(settingsTapped),
            identifier: AccessibilityID.Download.btSettings
        )

        dismissButton.image = NSImage.safeSystemSymbol("xmark")
        dismissButton.bezelStyle = .inline
        dismissButton.isBordered = false
        dismissButton.controlSize = .small
        dismissButton.target = self
        dismissButton.action = #selector(dismissTapped)
        dismissButton.toolTip = NSLocalizedString("不再提示", comment: "")
        dismissButton.setAccessibilityIdentifier(AccessibilityID.Download.btDismiss)

        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 6
        [retryButton, copyButton, websiteButton, settingsButton].forEach(buttonStack.addArrangedSubview)

        addSubview(iconView)
        addSubview(spinner)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(buttonStack)
        addSubview(dismissButton)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(12)
            make.width.height.equalTo(20)
        }
        spinner.snp.makeConstraints { make in
            make.center.equalTo(iconView)
            make.width.height.equalTo(16)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.top.equalToSuperview().offset(10)
            make.trailing.lessThanOrEqualTo(dismissButton.snp.leading).offset(-8)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }
        dismissButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.top.equalToSuperview().offset(8)
            make.width.height.equalTo(20)
        }
        buttonStack.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-8)
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
        }

        titleLabel.setAccessibilityIdentifier(AccessibilityID.Download.btStatusLabel)
        setAccessibilityIdentifier(AccessibilityID.Download.btBanner)
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func configureButton(
        _ button: NSButton,
        title: String,
        action: Selector,
        identifier: String
    ) {
        button.title = title
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.target = self
        button.action = action
        button.setAccessibilityIdentifier(identifier)
        button.setContentHuggingPriority(.required, for: .horizontal)
    }

    func configure(
        title: String,
        detail: String,
        isChecking: Bool,
        showRetry: Bool,
        showInstallHelp: Bool,
        showSettings: Bool
    ) {
        titleLabel.stringValue = title
        detailLabel.stringValue = detail
        titleLabel.toolTip = detail
        detailLabel.toolTip = detail
        retryButton.isHidden = !showRetry
        copyButton.isHidden = !showInstallHelp
        websiteButton.isHidden = !showInstallHelp
        settingsButton.isHidden = !showSettings
        dismissButton.isHidden = false

        iconView.isHidden = isChecking
        if isChecking {
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
    }

    @objc private func retryTapped() {
        onRetry?()
    }

    @objc private func copyTapped() {
        let command = "brew install transmission"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        detailLabel.stringValue = String(
            format: NSLocalizedString("已复制安装命令：%@", comment: ""),
            command
        )
    }

    @objc private func websiteTapped() {
        onWebsite?()
    }

    @objc private func settingsTapped() {
        onSettings?()
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }
}

// MARK: - Drop view

private final class DownloadDropView: NSView {

    var onDropSources: (([String]) -> Void)?

    private var isHighlighted = false {
        didSet { updateHighlight() }
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
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.clear.cgColor
        layer?.cornerRadius = 6
        registerForDraggedTypes([.fileURL, .string, .URL])
    }

    private func updateHighlight() {
        layer?.borderColor = isHighlighted
            ? NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
            : NSColor.clear.cgColor
    }

    private func sources(from draggingInfo: NSDraggingInfo) -> [String] {
        let pasteboard = draggingInfo.draggingPasteboard
        var values: [String] = []
        for item in pasteboard.pasteboardItems ?? [] {
            if let fileURLString = item.string(forType: .fileURL), !fileURLString.isEmpty {
                values.append(fileURLString)
            }
            if let string = item.string(forType: .string), !string.isEmpty {
                values.append(string)
            }
            if let urlString = item.string(forType: .URL), !urlString.isEmpty {
                values.append(urlString)
            }
        }
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let values = sources(from: sender)
        guard !values.isEmpty else { return [] }
        isHighlighted = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        sources(from: sender).isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !sources(from: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let values = sources(from: sender)
        isHighlighted = false
        guard !values.isEmpty else { return false }
        onDropSources?(values)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isHighlighted = false
    }
}

// MARK: - Empty state

private final class DownloadEmptyStateView: NSView {

    var onAction: (() -> Void)?

    private let iconView = ImageView()
    private let titleLabel = DownloadViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 15, weight: .semibold),
        color: .labelColor,
        alignment: .center
    )
    private let detailLabel = DownloadViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 11.5),
        color: .secondaryLabelColor,
        alignment: .center
    )
    private let actionButton = NSButton(title: "", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityIdentifier(AccessibilityID.Download.emptyState)
        iconView.setScaling(.aspectFit)
        iconView.contentTintColor = .tertiaryLabelColor

        detailLabel.maximumNumberOfLines = 3
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.cell?.wraps = true
        detailLabel.cell?.isScrollable = false
        detailLabel.preferredMaxLayoutWidth = 360

        actionButton.bezelStyle = .rounded
        actionButton.target = self
        actionButton.action = #selector(actionTapped)
        actionButton.setAccessibilityIdentifier(AccessibilityID.Download.emptyAdd)
        actionButton.isHidden = true

        let stack = NSStackView(views: [iconView, titleLabel, detailLabel, actionButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(2, after: titleLabel)
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(38)
        }
        detailLabel.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(380)
        }
    }

    func configure(
        symbolName: String,
        title: String,
        detail: String,
        actionTitle: String?,
        onAction: (() -> Void)?
    ) {
        iconView.image = NSImage.safeSystemSymbol(symbolName)
        titleLabel.stringValue = title
        detailLabel.stringValue = detail
        self.onAction = onAction
        actionButton.title = actionTitle ?? ""
        actionButton.isHidden = actionTitle == nil
    }

    @objc private func actionTapped() {
        onAction?()
    }
}
