//
//  DownloadViewController.swift
//  AniXPlayer
//
//  macOS：下载中心主界面。
//

import Cocoa
import SnapKit

final class DownloadViewController: ViewController {

    var onPlayFiles: (([File], File) -> Void)?

    private let manager: DownloadManager

    private var displayTasks: [DownloadTask] = []
    private var selectedTaskIDs: Set<UUID> = []
    private var detailFilePaths: [String] = []
    private var isRestoringSelection = false
    private var btBannerHeight: NSLayoutConstraint?
    private var notificationToken: NSObjectProtocol?

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
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 640))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("下载中心", comment: "")
        view.setAccessibilityIdentifier(AccessibilityID.Download.root)

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
        detailFileTable.addTableColumn(column)
        detailFileTable.headerView = nil
        detailFileTable.rowHeight = 22
        detailFileTable.dataSource = self
        detailFileTable.delegate = self
        detailFileTable.setAccessibilityIdentifier(AccessibilityID.Download.detailFiles)
        detailFileTable.target = self
        detailFileTable.doubleAction = #selector(detailFileDoubleClicked)

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
        btBanner.onInstall = {
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
        if let error = manager.storeError {
            emptyStateView.configure(
                symbolName: "exclamationmark.triangle",
                title: NSLocalizedString("下载中心无法打开", comment: ""),
                detail: error.localizedDescription,
                actionTitle: nil,
                onAction: nil
            )
            emptyStateView.isHidden = false
            tableScroll.isHidden = true
            return
        }

        let query = makeQuery()
        let isFiltering = !query.trimmedSearchText.isEmpty || query.filter != .all
        let show: Bool
        if manager.tasks.isEmpty {
            emptyStateView.configure(
                symbolName: "arrow.down.circle",
                title: NSLocalizedString("还没有下载任务", comment: ""),
                detail: NSLocalizedString("添加磁力链接、.torrent 种子或 HTTP/HTTPS 直链开始下载。", comment: ""),
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

        let single = selected.count == 1 ? selected[0] : nil
        openFolderButton.isEnabled = single != nil
        playButton.isEnabled = selected.contains { task in
            manager.completedPlaybackURL(for: task) != nil
                || manager.streamingPlaybackURL(for: task) != nil
        }

        if let task = single {
            if manager.completedPlaybackURL(for: task) != nil {
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
            detailTitleLabel.stringValue = NSLocalizedString("选择一个任务查看详情", comment: "")
            detailStatusLabel.stringValue = ""
            detailErrorLabel.stringValue = ""
            detailFilePaths = []
            detailFileTable.reloadData()
            return
        }

        detailTitleLabel.stringValue = task.displayTitle
        detailTitleLabel.toolTip = task.source
        detailStatusLabel.stringValue = String(
            format: NSLocalizedString("%@ · %@ · %@ · 保存到 %@", comment: ""),
            task.kind.displayName,
            task.status.displayName,
            DownloadFormatting.bytesProgress(
                downloaded: task.downloadedBytes,
                total: task.totalBytes
            ),
            task.savePath
        )
        detailStatusLabel.toolTip = task.savePath

        if let error = task.errorMessage, !error.isEmpty {
            detailErrorLabel.stringValue = error
            detailErrorLabel.isHidden = false
        } else {
            detailErrorLabel.stringValue = ""
            detailErrorLabel.isHidden = true
        }

        detailFilePaths = task.filePaths
        detailFileTable.reloadData()
    }

    private func updateBTBanner() {
        let visible: Bool
        if !manager.preferences.enableBT {
            btBanner.configure(
                title: NSLocalizedString("BT 集成已关闭", comment: ""),
                detail: NSLocalizedString("磁力/种子任务不可用；可在下载设置中重新启用。", comment: ""),
                showRetry: false,
                showInstall: false
            )
            visible = false
        } else {
            switch manager.btState {
            case .available:
                visible = false
            case .checking:
                btBanner.configure(
                    title: NSLocalizedString("正在检测 BT 内核…", comment: ""),
                    detail: NSLocalizedString("磁力/种子任务需要本机 Transmission RPC。", comment: ""),
                    showRetry: false,
                    showInstall: true
                )
                visible = true
            case .unknown:
                btBanner.configure(
                    title: NSLocalizedString("BT 内核状态未知", comment: ""),
                    detail: NSLocalizedString("点击重试检测，或在下载设置中配置 RPC 地址。", comment: ""),
                    showRetry: true,
                    showInstall: true
                )
                visible = true
            case .unavailable:
                btBanner.configure(
                    title: NSLocalizedString("未检测到 BT 内核", comment: ""),
                    detail: NSLocalizedString("安装：brew install transmission，启动 transmission-daemon 后重试；默认 RPC 为 127.0.0.1:9091。", comment: ""),
                    showRetry: true,
                    showInstall: true
                )
                visible = true
            }
        }

        btBanner.isHidden = !visible
        btBannerHeight?.constant = visible ? 54 : 0
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
        let directory = (try? manager.preferences.ensureDefaultSaveDirectory())
            ?? manager.preferences.defaultSaveDirectoryURL
        let sheet = DownloadAddSheetViewController(
            defaultSavePath: directory.path,
            defaultBookmark: manager.preferences.defaultSaveBookmark
        )
        sheet.onSubmit = { [weak self] source, savePath, bookmark, completion in
            guard let self else { return }
            self.manager.add(
                rawSource: source,
                savePath: savePath,
                bookmark: bookmark
            ) { result in
                DispatchQueue.main.async {
                    completion(result.map { _ in () })
                }
            }
        }
        presentAsSheet(sheet)
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

    @objc private func settingsTapped() {
        let sheet = DownloadSettingsSheetViewController(preferences: manager.preferences)
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
        guard row >= 0, row < detailFilePaths.count else { return }
        playFile(at: detailFilePaths[row])
    }

    @objc private func openFolderTapped() {
        selectClickedRowIfNeeded()
        guard let task = selectedTasks().first else { return }

        let existingFile = task.filePaths.first { FileManager.default.fileExists(atPath: $0) }
        if let existingFile {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: existingFile)])
            return
        }

        let directory = URL(fileURLWithPath: task.savePath, isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) {
            NSWorkspace.shared.open(directory)
        } else {
            showAlert(
                title: NSLocalizedString("目录不存在", comment: ""),
                message: task.savePath
            )
        }
    }

    @objc private func playTapped() {
        selectClickedRowIfNeeded()
        let tasks = selectedTasks()
        guard !tasks.isEmpty else { return }

        let completedURLs = tasks.compactMap { manager.completedPlaybackURL(for: $0) }
        if !completedURLs.isEmpty {
            startPlayback(urls: completedURLs)
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
        let files = urls
            .filter { FileManager.default.fileExists(atPath: $0.path) }
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
        guard FileManager.default.fileExists(atPath: path) else {
            showAlert(
                title: NSLocalizedString("文件不存在", comment: ""),
                message: path
            )
            return
        }
        let file = LocalFile(with: URL(fileURLWithPath: path))
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
        tableView === self.tableView ? displayTasks.count : detailFilePaths.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        if tableView === detailFileTable {
            guard row < detailFilePaths.count else { return nil }
            return detailFileCell(for: detailFilePaths[row], in: detailFileTable)
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
        if identifier == "title" {
            cell.textField?.toolTip = task.source
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

    private func detailFileCell(for path: String, in table: NSTableView) -> NSView {
        let identifier = NSUserInterfaceItemIdentifier("download.cell.file")
        let cell: NSTableCellView
        if let reused = table.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier
            let label = NSTextField(labelWithString: "")
            label.font = .systemFont(ofSize: 11.5)
            label.lineBreakMode = .byTruncatingMiddle
            cell.textField = label
            cell.addSubview(label)
            label.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(4)
                make.centerY.equalToSuperview()
            }
        }

        let size = DownloadFileRules.existingFileSize(at: path)
        let sizeText = size.map { DownloadFormatting.byteCount($0) } ?? "—"
        let name = (path as NSString).lastPathComponent
        cell.textField?.stringValue = "\(name) · \(sizeText)"
        cell.textField?.toolTip = path
        cell.textField?.textColor = size == nil ? .tertiaryLabelColor : .labelColor
        return cell
    }
}

// MARK: - Context menu

extension DownloadViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
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
                    manager.completedPlaybackURL(for: $0) != nil
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

// MARK: - BT banner

private final class DownloadBTBannerView: NSView {

    var onRetry: (() -> Void)?
    var onInstall: (() -> Void)?

    private let iconView = ImageView()
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
    private let installButton = NSButton(title: "", target: nil, action: nil)

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
        setAccessibilityIdentifier(AccessibilityID.Download.btBanner)

        iconView.image = NSImage.safeSystemSymbol("exclamationmark.triangle.fill")
        iconView.contentTintColor = .systemOrange
        iconView.setScaling(.aspectFit)

        detailLabel.lineBreakMode = .byTruncatingTail

        retryButton.title = NSLocalizedString("重试检测", comment: "")
        retryButton.bezelStyle = .rounded
        retryButton.controlSize = .small
        retryButton.target = self
        retryButton.action = #selector(retryTapped)
        retryButton.setAccessibilityIdentifier(AccessibilityID.Download.btRetry)

        installButton.title = NSLocalizedString("安装说明", comment: "")
        installButton.bezelStyle = .rounded
        installButton.controlSize = .small
        installButton.target = self
        installButton.action = #selector(installTapped)
        installButton.setAccessibilityIdentifier(AccessibilityID.Download.btInstall)

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(retryButton)
        addSubview(installButton)

        setAccessibilityIdentifier(AccessibilityID.Download.btBanner)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.top.equalToSuperview().offset(8)
            make.trailing.lessThanOrEqualTo(retryButton.snp.leading).offset(-10)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualTo(retryButton.snp.leading).offset(-10)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }
        installButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(78)
        }
        retryButton.snp.makeConstraints { make in
            make.trailing.equalTo(installButton.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(78)
        }
        installButton.setContentHuggingPriority(.required, for: .horizontal)
        retryButton.setContentHuggingPriority(.required, for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setAccessibilityIdentifier(AccessibilityID.Download.btStatusLabel)
    }

    func configure(title: String, detail: String, showRetry: Bool, showInstall: Bool) {
        titleLabel.stringValue = title
        detailLabel.stringValue = detail
        retryButton.isHidden = !showRetry
        installButton.isHidden = !showInstall
        titleLabel.toolTip = detail
        detailLabel.toolTip = detail
    }

    @objc private func retryTapped() {
        onRetry?()
    }

    @objc private func installTapped() {
        onInstall?()
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
