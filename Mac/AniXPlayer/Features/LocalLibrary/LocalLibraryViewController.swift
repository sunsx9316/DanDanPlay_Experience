//
//  LocalLibraryViewController.swift
//  AniXPlayer
//
//  macOS：本地媒体库主界面（海报墙 + 文件夹侧栏 + 扫描/匹配状态）。
//

import Cocoa
import SnapKit
import Kingfisher

// MARK: - Snapshot

private struct LocalLibrarySnapshot {
    let folders: [LocalLibraryFolder]
    let counts: [Int64: Int]
    let files: [LocalLibraryFile]
    let statistics: LocalLibraryStatistics
}

// MARK: - Main view controller

final class LocalLibraryViewController: ViewController {

    var onPlayFiles: (([File], File) -> Void)?

    private static let sortDefaultsKey = "LocalLibrary.sort"
    private static let showMissingDefaultsKey = "LocalLibrary.showMissing"

    private let store: LocalLibraryStore?
    private let storeError: Error?
    private lazy var scanner: LocalLibraryScanner? = store.map { LocalLibraryScanner(store: $0) }
    private lazy var matcher: LocalLibraryMatcher? = store.map { LocalLibraryMatcher(store: $0) }
    private lazy var thumbnailProvider = LocalLibraryThumbnailProvider(store: store)

    private var folders: [LocalLibraryFolder] = []
    private var files: [LocalLibraryFile] = []
    private var cards: [LocalLibraryCard] = []
    private var counts: [Int64: Int] = [:]
    private var statistics = LocalLibraryStatistics()
    private var selectedFolderId: Int64?
    private var selectedCardIds: Set<String> = []

    private var isScanning = false
    private var isMatching = false
    private var reloadGeneration = 0
    private var searchWorkItem: DispatchWorkItem?

    private var showMissing: Bool {
        get { UserDefaults.standard.bool(forKey: Self.showMissingDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.showMissingDefaultsKey) }
    }

    private var currentSort: LocalLibrarySort {
        get {
            let raw = UserDefaults.standard.string(forKey: Self.sortDefaultsKey) ?? ""
            return LocalLibrarySort(rawValue: raw) ?? .title
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.sortDefaultsKey) }
    }

    // MARK: Views

    private let titleLabel = LocalLibraryViewController.makeLabel(
        NSLocalizedString("本地媒体库", comment: ""),
        font: .systemFont(ofSize: 24, weight: .bold),
        color: .labelColor
    )

    private lazy var searchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = NSLocalizedString("搜索番剧、文件名…", comment: "")
        field.delegate = self
        field.sendsSearchStringImmediately = false
        field.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.search)
        return field
    }()

    private lazy var filterControl: NSSegmentedControl = {
        let control = NSSegmentedControl(
            labels: LocalLibraryFilter.allCases.map(\.displayName),
            trackingMode: .selectOne,
            target: self,
            action: #selector(filterChanged)
        )
        control.selectedSegment = 0
        control.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.filter)
        return control
    }()

    private lazy var addFolderButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("添加文件夹…", comment: ""),
            target: self,
            action: #selector(addFolderTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.addFolder)
        return button
    }()

    private lazy var scanButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("扫描", comment: ""),
            target: self,
            action: #selector(scanTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.scan)
        return button
    }()

    private lazy var rematchButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("重新匹配", comment: ""),
            target: self,
            action: #selector(rematchTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.rematch)
        return button
    }()

    private lazy var playButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("播放", comment: ""),
            target: self,
            action: #selector(playSelectionTapped)
        )
        button.bezelStyle = .rounded
        button.isEnabled = false
        button.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.play)
        return button
    }()

    private lazy var matchCorrectionButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("匹配修正…", comment: ""),
            target: self,
            action: #selector(matchCorrectionTapped)
        )
        button.bezelStyle = .rounded
        button.isEnabled = false
        button.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.matchCorrection)
        return button
    }()

    private lazy var moreButton: NSButton = {
        let button = NSButton(
            image: NSImage.safeSystemSymbol("ellipsis.circle"),
            target: self,
            action: #selector(moreTapped)
        )
        button.isBordered = false
        button.bezelStyle = .inline
        button.toolTip = NSLocalizedString("更多批量操作", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.more)
        return button
    }()

    private let moreMenu = NSMenu()

    private lazy var sortPopup: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.addItems(withTitles: LocalLibrarySort.allCases.map(\.displayName))
        popup.selectItem(at: LocalLibrarySort.allCases.firstIndex(of: currentSort) ?? 0)
        popup.target = self
        popup.action = #selector(sortChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.sort)
        return popup
    }()

    private let summaryLabel = LocalLibraryViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor,
        alignment: .right
    )

    private let sidebarTitleLabel = LocalLibraryViewController.makeLabel(
        NSLocalizedString("媒体库文件夹", comment: ""),
        font: .systemFont(ofSize: 12, weight: .semibold),
        color: .secondaryLabelColor
    )

    private lazy var folderMenuButton: NSButton = {
        let button = NSButton(
            image: NSImage.safeSystemSymbol("ellipsis.circle"),
            target: self,
            action: #selector(folderMenuTapped)
        )
        button.isBordered = false
        button.bezelStyle = .inline
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = NSLocalizedString("文件夹管理", comment: "")
        button.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.folders)
        return button
    }()

    private let folderMenu = NSMenu()

    private let sidebarContainer = LocalLibraryFlippedView()
    private let sidebarStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 2
        return stack
    }()
    private lazy var sidebarScroll: ScrollView<LocalLibraryFlippedView> = {
        let scroll = ScrollView(containerView: sidebarContainer)
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.horizontalScrollElasticity = .none
        return scroll
    }()

    private let gridContainer = NSView()
    private let emptyStateView = LocalLibraryEmptyStateView()

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 5
        layout.itemPadding = 14
        layout.sectionInset = NSEdgeInsets(top: 4, left: 0, bottom: 12, right: 0)
        layout.delegate = self
        return layout
    }()

    private lazy var collectionView: LocalLibraryCollectionView = {
        let view = LocalLibraryCollectionView()
        view.collectionViewLayout = waterfallLayout
        view.registerItem(class: LocalLibraryCollectionViewCell.self)
        view.dataSource = self
        view.delegate = self
        view.isSelectable = true
        view.allowsMultipleSelection = true
        view.allowsEmptySelection = true
        view.backgroundColors = [.clear]
        view.onDoubleClick = { [weak self] indexPath in
            self?.activateCard(at: indexPath)
        }
        view.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.grid)
        return view
    }()

    private lazy var gridScroll: ScrollView<LocalLibraryCollectionView> = {
        let scroll = ScrollView(containerView: collectionView)
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.horizontalScrollElasticity = .none
        return scroll
    }()

    private let statusLabel = LocalLibraryViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 11.5),
        color: .secondaryLabelColor
    )

    private let bottomInfoLabel = LocalLibraryViewController.makeLabel(
        NSLocalizedString("单击选择，双击播放或打开剧集；按住 ⌘ 可多选", comment: ""),
        font: .systemFont(ofSize: 11),
        color: .tertiaryLabelColor
    )

    private lazy var progressIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .bar
        indicator.isIndeterminate = false
        indicator.minValue = 0
        indicator.maxValue = 1
        indicator.isHidden = true
        return indicator
    }()

    private let separator = NSBox()

    // MARK: Init

    init(store: LocalLibraryStore?, storeError: Error?) {
        self.store = store
        self.storeError = storeError
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 720))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("本地媒体库", comment: "")
        view.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.root)

        setupLayout()
        setupSidebar()
        rebuildMoreMenu()
        reloadData()
    }

    deinit {
        searchWorkItem?.cancel()
        scanner?.cancel()
        matcher?.cancel()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutSidebar()
        layoutGrid()
    }

    /// 窗口关闭时停止后台工作，避免扫描/匹配在用户关闭界面后继续跑。
    func cancelOperations() {
        searchWorkItem?.cancel()
        scanner?.cancel()
        matcher?.cancel()
    }

    // MARK: Setup

    private func setupLayout() {
        view.addSubview(titleLabel)
        view.addSubview(addFolderButton)
        view.addSubview(scanButton)
        view.addSubview(rematchButton)
        view.addSubview(playButton)
        view.addSubview(matchCorrectionButton)
        view.addSubview(moreButton)
        view.addSubview(searchField)
        view.addSubview(filterControl)
        view.addSubview(sortPopup)
        view.addSubview(summaryLabel)
        view.addSubview(separator)
        view.addSubview(sidebarTitleLabel)
        view.addSubview(folderMenuButton)
        view.addSubview(sidebarScroll)
        view.addSubview(gridContainer)
        view.addSubview(statusLabel)
        view.addSubview(progressIndicator)
        view.addSubview(bottomInfoLabel)

        gridContainer.addSubview(gridScroll)
        gridContainer.addSubview(emptyStateView)

        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(18)
        }
        moreButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(titleLabel)
            make.width.height.equalTo(24)
        }
        matchCorrectionButton.snp.makeConstraints { make in
            make.trailing.equalTo(moreButton.snp.leading).offset(-8)
            make.centerY.equalTo(titleLabel)
        }
        playButton.snp.makeConstraints { make in
            make.trailing.equalTo(matchCorrectionButton.snp.leading).offset(-8)
            make.centerY.equalTo(titleLabel)
        }
        rematchButton.snp.makeConstraints { make in
            make.trailing.equalTo(playButton.snp.leading).offset(-8)
            make.centerY.equalTo(titleLabel)
        }
        scanButton.snp.makeConstraints { make in
            make.trailing.equalTo(rematchButton.snp.leading).offset(-8)
            make.centerY.equalTo(titleLabel)
        }
        addFolderButton.snp.makeConstraints { make in
            make.trailing.equalTo(scanButton.snp.leading).offset(-8)
            make.centerY.equalTo(titleLabel)
        }

        searchField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.width.equalTo(220)
        }
        filterControl.snp.makeConstraints { make in
            make.leading.equalTo(searchField.snp.trailing).offset(10)
            make.centerY.equalTo(searchField)
            make.width.equalTo(292)
        }
        sortPopup.snp.makeConstraints { make in
            make.leading.equalTo(filterControl.snp.trailing).offset(8)
            make.centerY.equalTo(searchField)
            make.width.equalTo(112)
        }
        summaryLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(sortPopup.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(searchField)
        }

        separator.boxType = .separator
        separator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(searchField.snp.bottom).offset(12)
            make.height.equalTo(1)
        }

        sidebarTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(separator.snp.bottom).offset(12)
        }
        folderMenuButton.snp.makeConstraints { make in
            make.trailing.equalTo(sidebarScroll.snp.trailing)
            make.centerY.equalTo(sidebarTitleLabel)
            make.width.height.equalTo(20)
        }
        sidebarScroll.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.width.equalTo(226)
            make.top.equalTo(sidebarTitleLabel.snp.bottom).offset(6)
            make.bottom.equalTo(statusLabel.snp.top).offset(-8)
        }
        gridContainer.snp.makeConstraints { make in
            make.leading.equalTo(sidebarScroll.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalTo(separator.snp.bottom).offset(8)
            make.bottom.equalTo(statusLabel.snp.top).offset(-8)
        }
        gridScroll.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
            make.top.greaterThanOrEqualToSuperview().offset(24)
            make.bottom.lessThanOrEqualToSuperview().offset(-24)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(bottomInfoLabel.snp.top).offset(-24)
            make.trailing.lessThanOrEqualTo(progressIndicator.snp.leading).offset(-10)
        }
        progressIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(statusLabel)
            make.width.equalTo(170)
            make.height.equalTo(8)
        }
        bottomInfoLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-10)
        }
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bottomInfoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.status)

        gridScroll.hasVerticalScroller = true
        gridScroll.hasHorizontalScroller = false
        gridScroll.autohidesScrollers = true
        gridScroll.drawsBackground = false
        gridScroll.borderType = .noBorder
        gridScroll.horizontalScrollElasticity = .none

        separator.boxType = .separator
    }

    private func setupSidebar() {
        sidebarContainer.addSubview(sidebarStack)
        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .width
        sidebarStack.spacing = 2
        sidebarStack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
    }

    // MARK: Layout helpers

    private func layoutSidebar() {
        let width = sidebarScroll.contentView.bounds.width
        guard width > 0 else { return }
        let height = max(sidebarStack.fittingSize.height, sidebarScroll.contentView.bounds.height)
        if sidebarContainer.frame.width != width || sidebarContainer.frame.height != height {
            sidebarContainer.frame = NSRect(x: 0, y: 0, width: width, height: height)
            sidebarStack.layoutSubtreeIfNeeded()
        }
    }

    private func layoutGrid() {
        let bounds = gridScroll.contentView.bounds
        guard bounds.width > 0 else { return }

        let columns = max(2, min(7, Int((bounds.width + 14) / (176 + 14))))
        if waterfallLayout.columnCount != columns {
            waterfallLayout.columnCount = columns
        }

        let height = max(gridScroll.contentView.bounds.height, waterfallLayout.collectionViewContentSize.height)
        if collectionView.frame.width != bounds.width || abs(collectionView.frame.height - height) > 1 {
            collectionView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: height)
            waterfallLayout.invalidateLayout()
        }
    }

    // MARK: Data

    private func makeQuery() -> LocalLibraryQuery {
        var query = LocalLibraryQuery()
        query.searchText = searchField.stringValue
        let index = max(0, min(filterControl.selectedSegment, LocalLibraryFilter.allCases.count - 1))
        query.filter = LocalLibraryFilter.allCases[index]
        query.folderId = selectedFolderId
        query.sort = currentSort
        query.includesMissing = showMissing || query.filter == .missing
        return query
    }

    private func reloadData(completion: (() -> Void)? = nil) {
        guard let store else {
            renderStoreError()
            completion?()
            return
        }

        reloadGeneration += 1
        let generation = reloadGeneration
        let query = makeQuery()

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let snapshot = LocalLibrarySnapshot(
                    folders: try store.folders(),
                    counts: try store.fileCounts(),
                    files: try store.files(query: query),
                    statistics: try store.statistics()
                )
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.reloadGeneration == generation else { return }
                    self.apply(snapshot)
                    completion?()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.reloadGeneration == generation else { return }
                    self.showStatus(error.localizedDescription, isError: true)
                    completion?()
                }
            }
        }
    }

    private func apply(_ snapshot: LocalLibrarySnapshot) {
        folders = snapshot.folders
        counts = snapshot.counts
        files = snapshot.files
        statistics = snapshot.statistics
        cards = LocalLibraryGrouping.cards(from: snapshot.files, sort: currentSort)
        thumbnailProvider.updateFolders(snapshot.folders)

        if let selectedFolderId, !folders.contains(where: { $0.id == selectedFolderId }) {
            self.selectedFolderId = nil
        }
        let availableCardIds = Set(cards.map(\.id))
        selectedCardIds.formIntersection(availableCardIds)

        rebuildSidebar()
        collectionView.reloadData()
        restoreSelection()
        updateSummary()
        updateEmptyState()
        updateBottomInfo()
        updateActionAvailability()
        layoutSidebar()
        layoutGrid()
    }

    private func restoreSelection() {
        let indexPaths = Set(cards.enumerated().compactMap { index, card -> IndexPath? in
            selectedCardIds.contains(card.id) ? IndexPath(item: index, section: 0) : nil
        })
        if !indexPaths.isEmpty {
            collectionView.selectItems(at: indexPaths, scrollPosition: [])
        }
    }

    private func rebuildSidebar() {
        sidebarStack.arrangedSubviews.forEach {
            sidebarStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let allRow = LocalLibraryFolderRowView(
            title: NSLocalizedString("全部文件", comment: ""),
            count: statistics.totalCount,
            identifier: AccessibilityID.LocalLibrary.folderAll,
            canRemove: false
        )
        allRow.isSelectedRow = selectedFolderId == nil
        allRow.onSelect = { [weak self] in
            guard let self else { return }
            self.selectedFolderId = nil
            self.reloadData()
        }
        sidebarStack.addArrangedSubview(allRow)
        allRow.snp.makeConstraints { make in
            make.width.equalTo(sidebarStack)
            make.height.equalTo(38)
        }

        for folder in folders {
            let row = LocalLibraryFolderRowView(
                title: folder.name,
                count: counts[folder.id] ?? 0,
                identifier: "\(AccessibilityID.LocalLibrary.folderPrefix)\(folder.id)",
                canRemove: true
            )
            row.toolTip = folder.path
            row.isSelectedRow = selectedFolderId == folder.id
            row.onSelect = { [weak self] in
                guard let self else { return }
                self.selectedFolderId = folder.id
                self.reloadData()
            }
            row.onRemove = { [weak self] in
                self?.confirmRemove(folder: folder)
            }
            row.setAccessibilityIdentifier("\(AccessibilityID.LocalLibrary.folderPrefix)\(folder.id)")
            row.setAccessibilityLabel("\(folder.name)，\(counts[folder.id] ?? 0) 个视频")
            sidebarStack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.width.equalTo(sidebarStack)
                make.height.equalTo(46)
            }
        }

        sidebarStack.layoutSubtreeIfNeeded()
        rebuildFolderMenu()
    }

    private func rebuildFolderMenu() {
        folderMenu.removeAllItems()
        folderMenu.autoenablesItems = false

        let addItem = NSMenuItem(
            title: NSLocalizedString("添加文件夹…", comment: ""),
            action: #selector(folderMenuAddTapped),
            keyEquivalent: ""
        )
        addItem.target = self
        addItem.isEnabled = !isScanning && !isMatching
        folderMenu.addItem(addItem)

        guard !folders.isEmpty else {
            folderMenu.addItem(NSMenuItem.separator())
            let emptyItem = NSMenuItem(
                title: NSLocalizedString("暂无文件夹", comment: ""),
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            folderMenu.addItem(emptyItem)
            return
        }

        folderMenu.addItem(NSMenuItem.separator())
        for folder in folders {
            let item = NSMenuItem(
                title: String(format: NSLocalizedString("移除「%@」…", comment: ""), folder.name),
                action: #selector(folderMenuRemoveTapped(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = Int(folder.id)
            item.isEnabled = !isScanning && !isMatching
            item.setAccessibilityIdentifier("\(AccessibilityID.LocalLibrary.removeFolderPrefix)\(folder.id)")
            folderMenu.addItem(item)
        }
    }

    private func updateSummary() {
        summaryLabel.stringValue = String(
            format: NSLocalizedString("共 %d 个视频 · 已匹配 %d · 未匹配 %d · 缺失 %d", comment: ""),
            statistics.totalCount,
            statistics.matchedCount,
            statistics.unmatchedCount,
            statistics.missingCount
        )
        summaryLabel.toolTip = summaryLabel.stringValue + " · " + NSLocalizedString(
            "缺失记录只存在于数据库中，可筛选后清理。",
            comment: ""
        )
    }

    private func updateEmptyState() {
        guard storeError == nil, let _ = store else {
            emptyStateView.isHidden = false
            gridScroll.isHidden = true
            return
        }

        let query = makeQuery()
        let hasQuery = !query.trimmedSearchText.isEmpty || query.filter != .all || query.folderId != nil
        let show: Bool
        if isScanning {
            emptyStateView.configure(
                symbolName: "arrow.triangle.2.circlepath",
                title: NSLocalizedString("正在扫描媒体库…", comment: ""),
                detail: NSLocalizedString("扫描在后台进行，可以继续浏览已索引的视频。", comment: ""),
                actionTitle: nil,
                onAction: nil
            )
            show = files.isEmpty
        } else if folders.isEmpty {
            emptyStateView.configure(
                symbolName: "folder.badge.plus",
                title: NSLocalizedString("还没有添加媒体库文件夹", comment: ""),
                detail: NSLocalizedString("选择一个文件夹，弹弹play 会递归扫描其中的视频并尝试匹配弹幕库。", comment: ""),
                actionTitle: NSLocalizedString("添加文件夹…", comment: ""),
                onAction: { [weak self] in self?.addFolderTapped() }
            )
            show = true
        } else if files.isEmpty {
            if hasQuery {
                emptyStateView.configure(
                    symbolName: "magnifyingglass",
                    title: NSLocalizedString("没有符合条件的视频", comment: ""),
                    detail: query.filter == .missing
                        ? NSLocalizedString("当前范围没有缺失记录。", comment: "")
                        : NSLocalizedString("尝试清空搜索词或切换筛选条件。", comment: ""),
                    actionTitle: nil,
                    onAction: nil
                )
            } else {
                emptyStateView.configure(
                    symbolName: "film.stack",
                    title: NSLocalizedString("还没有索引到视频", comment: ""),
                    detail: NSLocalizedString("点击扫描，递归读取文件夹中的视频文件。", comment: ""),
                    actionTitle: NSLocalizedString("扫描文件夹", comment: ""),
                    actionIdentifier: AccessibilityID.LocalLibrary.scan,
                    onAction: { [weak self] in self?.scanTapped() }
                )
            }
            show = true
        } else {
            show = false
        }

        emptyStateView.isHidden = !show
        gridScroll.isHidden = show
    }

    private func updateBottomInfo() {
        let selected = selectedCards()
        if selected.count == 1, let card = selected.first {
            switch card {
            case .group(let group):
                let missing = group.missingCount > 0
                    ? " · " + String(format: NSLocalizedString("缺失 %d 集", comment: ""), group.missingCount)
                    : ""
                bottomInfoLabel.stringValue = String(
                    format: NSLocalizedString("%@ · %d 集 · %@%@", comment: ""),
                    group.animeTitle,
                    group.episodeCount,
                    group.sizeText,
                    missing
                )
                bottomInfoLabel.toolTip = group.primaryFile?.path
            case .file(let file):
                bottomInfoLabel.stringValue = detailText(for: file)
                bottomInfoLabel.toolTip = file.path
            }
        } else if selected.count > 1 {
            let fileCount = selected.reduce(0) { $0 + $1.files.count }
            bottomInfoLabel.stringValue = String(
                format: NSLocalizedString("已选择 %d 项（%d 个文件）", comment: ""),
                selected.count,
                fileCount
            )
            bottomInfoLabel.toolTip = nil
        } else {
            bottomInfoLabel.stringValue = NSLocalizedString(
                "单击选择，双击播放或打开剧集；按住 ⌘ 可多选",
                comment: ""
            )
            bottomInfoLabel.toolTip = nil
        }
    }

    private func detailText(for file: LocalLibraryFile) -> String {
        var parts = [file.path, file.sizeText, file.matchStatusText]
        if file.isMissing {
            parts.append(NSLocalizedString("缺失", comment: ""))
        }
        if !file.mediaMetadata.isEmpty {
            parts.append(file.mediaMetadata.displayText)
        }
        return parts.joined(separator: " · ")
    }

    private func renderStoreError() {
        let message = storeError?.localizedDescription
            ?? NSLocalizedString("媒体库数据库不可用", comment: "")
        showStatus(message, isError: true)
        emptyStateView.configure(
            symbolName: "exclamationmark.triangle",
            title: NSLocalizedString("媒体库无法打开", comment: ""),
            detail: message,
            actionTitle: nil,
            onAction: nil
        )
        emptyStateView.isHidden = false
        gridScroll.isHidden = true
    }

    private func showStatus(_ text: String, isError: Bool = false) {
        statusLabel.stringValue = text
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
        statusLabel.toolTip = text
    }

    // MARK: Folder actions

    @objc private func filterChanged() {
        reloadData()
    }

    @objc private func sortChanged() {
        let index = max(0, min(sortPopup.indexOfSelectedItem, LocalLibrarySort.allCases.count - 1))
        currentSort = LocalLibrarySort.allCases[index]
        reloadData()
    }

    @objc private func moreTapped() {
        moreMenu.popUp(
            positioning: nil,
            at: NSPoint(x: moreButton.bounds.width, y: moreButton.bounds.height + 4),
            in: moreButton
        )
    }

    // MARK: Selection / batch actions

    private func selectedCards() -> [LocalLibraryCard] {
        cards.filter { selectedCardIds.contains($0.id) }
    }

    private func updateActionAvailability() {
        let selected = selectedCards()
        let playable = selected.contains { card in
            card.files.contains(where: { !$0.isMissing })
        }
        playButton.isEnabled = playable
        matchCorrectionButton.isEnabled = !selected.isEmpty && !isScanning && !isMatching
        rematchButton.isEnabled = !isScanning

        for item in moreMenu.items {
            switch item.tag {
            case 1:
                item.isEnabled = !selected.isEmpty && !isScanning && !isMatching
            case 2:
                item.isEnabled = playable && !isScanning && !isMatching
            case 3:
                item.isEnabled = !selected.isEmpty && !isScanning && !isMatching
            case 4:
                item.isEnabled = statistics.missingCount > 0 && !isScanning && !isMatching
            case 6:
                item.isEnabled = selected.contains { $0.files.contains(where: \.isMatched) }
                    && !isScanning && !isMatching
            default:
                break
            }
        }
    }

    private func rebuildMoreMenu() {
        moreMenu.removeAllItems()
        moreMenu.autoenablesItems = false

        let rematchItem = NSMenuItem(
            title: NSLocalizedString("重新匹配所选", comment: ""),
            action: #selector(rematchSelectedTapped),
            keyEquivalent: ""
        )
        rematchItem.target = self
        rematchItem.tag = 1
        rematchItem.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.rematchSelected)
        moreMenu.addItem(rematchItem)

        let clearMatchItem = NSMenuItem(
            title: NSLocalizedString("取消匹配所选…", comment: ""),
            action: #selector(clearSelectedMatchTapped),
            keyEquivalent: ""
        )
        clearMatchItem.target = self
        clearMatchItem.tag = 6
        clearMatchItem.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.clearMatchSelected)
        moreMenu.addItem(clearMatchItem)

        let revealItem = NSMenuItem(
            title: NSLocalizedString("在 Finder 中显示", comment: ""),
            action: #selector(revealSelectedTapped),
            keyEquivalent: ""
        )
        revealItem.target = self
        revealItem.tag = 2
        revealItem.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.revealSelected)
        moreMenu.addItem(revealItem)

        let removeItem = NSMenuItem(
            title: NSLocalizedString("移出媒体库…", comment: ""),
            action: #selector(removeSelectedTapped),
            keyEquivalent: ""
        )
        removeItem.target = self
        removeItem.tag = 3
        removeItem.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.removeSelected)
        moreMenu.addItem(removeItem)

        moreMenu.addItem(NSMenuItem.separator())

        let cleanItem = NSMenuItem(
            title: NSLocalizedString("清理缺失记录…", comment: ""),
            action: #selector(cleanMissingTapped),
            keyEquivalent: ""
        )
        cleanItem.target = self
        cleanItem.tag = 4
        cleanItem.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.cleanMissing)
        moreMenu.addItem(cleanItem)

        let showMissingItem = NSMenuItem(
            title: NSLocalizedString("在列表中显示缺失文件", comment: ""),
            action: #selector(toggleShowMissingTapped),
            keyEquivalent: ""
        )
        showMissingItem.target = self
        showMissingItem.tag = 5
        showMissingItem.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.showMissing)
        showMissingItem.state = showMissing ? .on : .off
        moreMenu.addItem(showMissingItem)

        updateActionAvailability()
    }

    @objc private func toggleShowMissingTapped() {
        showMissing.toggle()
        rebuildMoreMenu()
        reloadData()
    }

    @objc private func rematchSelectedTapped() {
        let selectedFiles = selectedCards().flatMap(\.files)
        guard !selectedFiles.isEmpty else { return }
        guard !isScanning else { return }
        startMatching(files: selectedFiles)
    }

    @objc private func clearSelectedMatchTapped() {
        let selectedFiles = selectedCards().flatMap(\.files).filter(\.isMatched)
        guard !selectedFiles.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = String(
            format: NSLocalizedString("取消所选 %d 个文件的匹配？", comment: ""),
            selectedFiles.count
        )
        alert.informativeText = NSLocalizedString(
            "会清空这些文件的番剧、剧集和海报信息；文件本身不会被删除。",
            comment: ""
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("取消匹配", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("不取消", comment: ""))

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn, let self, let store = self.store else { return }
            var failed = 0
            for file in selectedFiles {
                do {
                    _ = try store.clearMatch(fileId: file.id)
                } catch {
                    failed += 1
                }
            }
            if failed > 0 {
                self.showStatus(
                    String(format: NSLocalizedString("有 %d 个文件取消失败", comment: ""), failed),
                    isError: true
                )
            } else {
                self.showStatus(String(
                    format: NSLocalizedString("已取消 %d 个文件的匹配", comment: ""),
                    selectedFiles.count
                ))
            }
            self.reloadData()
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    @objc private func revealSelectedTapped() {
        let urls = selectedCards()
            .flatMap(\.files)
            .filter { !$0.isMissing }
            .map(\.fileURL)
        guard !urls.isEmpty else {
            showStatus(NSLocalizedString("所选文件已缺失，无法在 Finder 中显示。", comment: ""), isError: true)
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    @objc private func removeSelectedTapped() {
        let selected = selectedCards()
        let fileIds = selected.flatMap(\.files).map(\.id)
        guard !fileIds.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = String(
            format: NSLocalizedString("从媒体库移除所选 %d 个文件？", comment: ""),
            fileIds.count
        )
        alert.informativeText = NSLocalizedString("只会删除媒体库索引，不会删除磁盘上的文件。", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("移除", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn, let self, let store = self.store else { return }
            do {
                let removed = try store.deleteFiles(ids: fileIds)
                self.selectedCardIds.removeAll()
                self.showStatus(String(
                    format: NSLocalizedString("已从媒体库移除 %d 个文件", comment: ""),
                    removed
                ))
                self.reloadData()
            } catch {
                self.showStatus(error.localizedDescription, isError: true)
            }
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    @objc private func cleanMissingTapped() {
        guard let store else { return }
        let folderId = selectedFolderId
        let count = (try? store.missingCount(folderId: folderId)) ?? 0
        guard count > 0 else {
            showStatus(NSLocalizedString("当前范围没有缺失记录", comment: ""))
            return
        }

        let alert = NSAlert()
        alert.messageText = String(
            format: NSLocalizedString("清理 %d 条缺失记录？", comment: ""),
            count
        )
        alert.informativeText = NSLocalizedString(
            "只会删除媒体库中的缺失索引，不会影响磁盘文件。以后重新扫描仍可恢复。",
            comment: ""
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("清理", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            do {
                let removed = try store.deleteMissingFiles(folderId: folderId)
                self.selectedCardIds.removeAll()
                self.showStatus(String(
                    format: NSLocalizedString("已清理 %d 条缺失记录", comment: ""),
                    removed
                ))
                self.reloadData()
            } catch {
                self.showStatus(error.localizedDescription, isError: true)
            }
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    @objc private func playSelectionTapped() {
        let selected = selectedCards()
        guard !selected.isEmpty else {
            showStatus(NSLocalizedString("请先选择要播放的视频", comment: ""))
            return
        }
        if selected.count == 1, let card = selected.first {
            activate(card: card)
            return
        }
        let orderedFiles = selected.flatMap { card in
            card.files.filter { !$0.isMissing }
        }
        guard let start = orderedFiles.first else {
            showStatus(NSLocalizedString("所选文件均已缺失，无法播放。", comment: ""), isError: true)
            return
        }
        play(files: orderedFiles, start: start)
    }

    @objc private func matchCorrectionTapped() {
        guard let store else { return }
        let targets = selectedCards().flatMap(\.files)
        guard !targets.isEmpty else {
            showStatus(NSLocalizedString("请先选择要修正的条目", comment: ""))
            return
        }
        let editor = LocalLibraryMatchEditorViewController(store: store, targets: targets)
        editor.onApplied = { [weak self] in
            self?.reloadData()
        }
        presentAsSheet(editor)
    }

    private func activateCard(at indexPath: IndexPath) {
        guard indexPath.item >= 0, indexPath.item < cards.count else { return }
        activate(card: cards[indexPath.item])
    }

    private func activate(card: LocalLibraryCard) {
        switch card {
        case .group(let group):
            showEpisodeList(for: group)
        case .file(let file):
            guard !file.isMissing else {
                showStatus(NSLocalizedString("文件已缺失，无法播放。", comment: ""), isError: true)
                return
            }
            play(files: [file], start: file)
        }
    }

    private func showEpisodeList(for group: LocalLibraryAnimeGroup) {
        let sheet = LocalLibraryEpisodeListViewController(group: group)
        sheet.onPlay = { [weak self] files, start in
            self?.play(files: files, start: start)
        }
        presentAsSheet(sheet)
    }

    @objc private func folderMenuTapped() {
        folderMenu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: folderMenuButton.bounds.height + 4),
            in: folderMenuButton
        )
    }

    @objc private func folderMenuAddTapped() {
        addFolderTapped()
    }

    @objc private func folderMenuRemoveTapped(_ sender: NSMenuItem) {
        guard let folder = folders.first(where: { $0.id == Int64(sender.tag) }) else { return }
        confirmRemove(folder: folder)
    }

    @objc private func addFolderTapped() {
        guard let store else { return }
        guard !isScanning else {
            showStatus(NSLocalizedString("扫描进行中，请稍后再添加文件夹。", comment: ""))
            return
        }
        guard !isMatching else {
            showStatus(NSLocalizedString("匹配进行中，请稍后再添加文件夹。", comment: ""))
            return
        }

        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("选择媒体库文件夹", comment: "")
        panel.message = NSLocalizedString("弹弹play 会递归扫描该文件夹内的视频文件。", comment: "")
        panel.prompt = NSLocalizedString("添加", comment: "")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let self else { return }
            self.addFolders(urls: panel.urls, store: store)
        }

        if let window = view.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    private func addFolders(urls: [URL], store: LocalLibraryStore) {
        var conflicts: [(name: String, detail: String)] = []
        var consideredPaths = folders.map(\.path)

        for url in urls {
            let path = url.standardizedFileURL.path
            let overlaps = LocalLibraryFolderRules.overlaps(newPath: path, existingPaths: consideredPaths)
                .filter { $0.relationship != .same }
            consideredPaths.append(path)
            guard !overlaps.isEmpty else { continue }
            let detail = overlaps.map { overlap -> String in
                let existingName = LocalLibraryFormatting.folderName(for: overlap.path)
                switch overlap.relationship {
                case .newIsAncestor:
                    return String(
                        format: NSLocalizedString("包含已有文件夹「%@」", comment: ""),
                        existingName
                    )
                case .newIsDescendant:
                    return String(
                        format: NSLocalizedString("位于已有文件夹「%@」内", comment: ""),
                        existingName
                    )
                case .same:
                    return existingName
                case .none:
                    return existingName
                }
            }.joined(separator: "；")
            conflicts.append((url.lastPathComponent, detail))
        }

        let performAdd = { [weak self] in
            guard let self else { return }
            var addedAny = false
            var lastError: Error?
            for url in urls {
                do {
                    let bookmark = (try? url.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )) ?? (try? url.bookmarkData(
                        options: [],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ))
                    _ = try store.addFolder(path: url.path, bookmark: bookmark)
                    addedAny = true
                } catch {
                    lastError = error
                }
            }

            if let lastError {
                self.showStatus(lastError.localizedDescription, isError: true)
            }
            if addedAny {
                self.selectedFolderId = nil
                self.reloadData { [weak self] in
                    guard let self, !self.isScanning else { return }
                    self.startScan()
                }
            }
        }

        guard !conflicts.isEmpty else {
            performAdd()
            return
        }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("文件夹与已有媒体库重叠", comment: "")
        let detailLines = conflicts.map { "\($0.name)：\($0.detail)" }.joined(separator: "\n")
        alert.informativeText = String(
            format: NSLocalizedString(
                "%@\n\n重叠范围内的视频只保留首次入库的文件夹归属，不会重复计数；移除其中一个文件夹也不会删除另一个文件夹的索引。是否仍然添加？",
                comment: ""
            ),
            detailLines
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("仍然添加", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        let handle: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertFirstButtonReturn else { return }
            performAdd()
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    private func presentFolderAccessAlert(for failure: LocalLibraryScanFailure) {
        guard let folder = folders.first(where: { $0.id == failure.folderId }) else { return }
        let alert = NSAlert()
        alert.messageText = String(
            format: NSLocalizedString("无法访问媒体库文件夹「%@」", comment: ""),
            folder.name
        )
        alert.informativeText = String(
            format: NSLocalizedString(
                "%@\n\n可能是文件夹已移动或访问权限失效。重新选择该文件夹即可更新授权。",
                comment: ""
            ),
            failure.message
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("重新选择文件夹…", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("稍后", comment: ""))

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.rechooseFolder(folder)
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    private func rechooseFolder(_ folder: LocalLibraryFolder) {
        guard let store else { return }
        let panel = NSOpenPanel()
        panel.title = String(
            format: NSLocalizedString("重新选择「%@」", comment: ""),
            folder.name
        )
        panel.message = NSLocalizedString("请选择原来的媒体库文件夹，以更新访问授权。", comment: "")
        panel.prompt = NSLocalizedString("授权", comment: "")
        panel.directoryURL = folder.fileURL
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let self, let url = panel.url else { return }
            let selectedPath = url.standardizedFileURL.path
            guard selectedPath == folder.path else {
                self.showStatus(
                    String(
                        format: NSLocalizedString("请选择原文件夹：%@", comment: ""),
                        folder.path
                    ),
                    isError: true
                )
                return
            }
            let bookmark = (try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )) ?? (try? url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ))
            do {
                try store.updateFolderBookmark(id: folder.id, bookmark: bookmark)
                if let index = self.folders.firstIndex(where: { $0.id == folder.id }) {
                    self.folders[index].bookmark = bookmark
                }
                self.showStatus(NSLocalizedString("已更新文件夹授权，正在重新扫描…", comment: ""))
                self.reloadData { [weak self] in
                    guard let self, !self.isScanning else { return }
                    self.startScan()
                }
            } catch {
                self.showStatus(error.localizedDescription, isError: true)
            }
        }

        if let window = view.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    private func confirmRemove(folder: LocalLibraryFolder) {
        guard !isScanning else {
            showStatus(NSLocalizedString("扫描进行中，请稍后再移除文件夹。", comment: ""))
            return
        }
        guard !isMatching else {
            showStatus(NSLocalizedString("匹配进行中，请稍后再移除文件夹。", comment: ""))
            return
        }
        let alert = NSAlert()
        alert.messageText = String(
            format: NSLocalizedString("移除媒体库文件夹「%@」？", comment: ""),
            folder.name
        )
        alert.informativeText = NSLocalizedString("只会从媒体库索引中移除，不会删除磁盘上的文件。", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("移除", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn, let self, let store = self.store else { return }
            do {
                let removed = try store.removeFolder(id: folder.id)
                if self.selectedFolderId == folder.id {
                    self.selectedFolderId = nil
                }
                self.showStatus(
                    String(format: NSLocalizedString("已移除文件夹「%@」及 %d 条索引", comment: ""), folder.name, removed)
                )
                self.reloadData()
            } catch {
                self.showStatus(error.localizedDescription, isError: true)
            }
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    // MARK: Scan

    @objc private func scanTapped() {
        guard let scanner else { return }

        if isScanning {
            scanner.cancel()
            showStatus(NSLocalizedString("正在取消扫描…", comment: ""))
            return
        }
        guard !isMatching else {
            showStatus(NSLocalizedString("匹配进行中，请稍后再扫描。", comment: ""))
            return
        }

        if folders.isEmpty {
            addFolderTapped()
            return
        }

        startScan()
    }

    private func startScan() {
        guard let scanner, !folders.isEmpty, !scanner.isScanning else { return }
        guard !isMatching else {
            showStatus(NSLocalizedString("匹配进行中，请稍后再扫描。", comment: ""))
            return
        }

        isScanning = true
        scanButton.title = NSLocalizedString("取消扫描", comment: "")
        addFolderButton.isEnabled = false
        rematchButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.isIndeterminate = false
        progressIndicator.doubleValue = 0
        showStatus(NSLocalizedString("正在准备扫描…", comment: ""))
        updateEmptyState()
        updateActionAvailability()
        rebuildFolderMenu()
        bottomInfoLabel.stringValue = NSLocalizedString("扫描在后台进行，可以继续浏览已索引的视频。", comment: "")

        scanner.startScan(
            folders: folders,
            progress: { [weak self] progress in
                guard let self else { return }
                self.progressIndicator.doubleValue = progress.fraction
                if progress.total > 0 {
                    self.showStatus(String(
                        format: NSLocalizedString("正在扫描 %d/%d：%@", comment: ""),
                        progress.scanned,
                        progress.total,
                        progress.currentFileName
                    ))
                } else {
                    self.showStatus(NSLocalizedString("正在扫描文件夹…", comment: ""))
                }
            },
            completion: { [weak self] summary in
                guard let self else { return }
                self.finishScan(summary)
            }
        )
    }

    private func finishScan(_ summary: LocalLibraryScanSummary) {
        isScanning = false
        scanButton.title = NSLocalizedString("扫描", comment: "")
        addFolderButton.isEnabled = true
        rematchButton.isEnabled = true
        progressIndicator.isHidden = true
        progressIndicator.doubleValue = 0
        rebuildFolderMenu()

        if let error = summary.errorMessage {            showStatus(error, isError: true)
        } else if summary.cancelled {
            showStatus(NSLocalizedString("已取消扫描", comment: ""))
        } else {
            showStatus(String(
                format: NSLocalizedString("扫描完成：新增 %d，更新 %d，未变化 %d，缺失 %d", comment: ""),
                summary.added,
                summary.updated,
                summary.unchanged,
                summary.markedMissing
            ))
        }

        reloadData { [weak self] in
            guard let self else { return }
            self.updateActionAvailability()
            if let failure = summary.folderFailures.first {
                self.presentFolderAccessAlert(for: failure)
            }
        }

        if !summary.cancelled && summary.folderFailures.isEmpty {
            autoMatchUnmatched()
        }
    }

    // MARK: Match

    @objc private func rematchTapped() {
        guard let matcher else { return }

        if matcher.isMatching {
            matcher.cancel()
            showStatus(NSLocalizedString("正在停止匹配…", comment: ""))
            return
        }
        guard !isScanning else { return }

        guard let store else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let files = (try? store.unmatchedFiles()) ?? []
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard !files.isEmpty else {
                    self.showStatus(NSLocalizedString("没有需要重新匹配的文件", comment: ""))
                    return
                }
                self.startMatching(files: files)
            }
        }
    }

    private func autoMatchUnmatched() {
        guard let store, let matcher, !matcher.isMatching else { return }
        DispatchQueue.global(qos: .utility).async {
            let files = (try? store.unmatchedFiles()) ?? []
            guard !files.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let matcher = self.matcher, !matcher.isMatching else { return }
                self.startMatching(files: files, automatic: true)
            }
        }
    }

    private func startMatching(files: [LocalLibraryFile], automatic: Bool = false) {
        guard let matcher else { return }

        isMatching = true
        rematchButton.title = NSLocalizedString("停止匹配", comment: "")
        scanButton.isEnabled = false
        addFolderButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.isIndeterminate = false
        progressIndicator.doubleValue = 0
        updateActionAvailability()
        rebuildFolderMenu()
        showStatus(
            automatic
                ? String(format: NSLocalizedString("正在自动匹配 %d 个文件…", comment: ""), files.count)
                : String(format: NSLocalizedString("正在重新匹配 %d 个文件…", comment: ""), files.count)
        )

        matcher.match(
            files: files,
            progress: { [weak self] done, total in
                guard let self else { return }
                self.progressIndicator.doubleValue = total > 0 ? Double(done) / Double(total) : 0
                self.showStatus(String(
                    format: NSLocalizedString("正在匹配 %d/%d…", comment: ""),
                    done,
                    total
                ))
            },
            completion: { [weak self] summary in
                guard let self else { return }
                self.isMatching = false
                self.rematchButton.title = NSLocalizedString("重新匹配", comment: "")
                self.rematchButton.isEnabled = true
                self.scanButton.isEnabled = true
                self.addFolderButton.isEnabled = true
                self.progressIndicator.isHidden = true
                self.progressIndicator.doubleValue = 0
                self.updateActionAvailability()
                self.rebuildFolderMenu()

                if summary.cancelled {
                    self.showStatus(NSLocalizedString("已停止匹配", comment: ""))
                } else if summary.failedCount > 0 {
                    self.showStatus(String(
                        format: NSLocalizedString("匹配完成：成功 %d，失败 %d", comment: ""),
                        summary.matchedCount,
                        summary.failedCount
                    ))
                } else {
                    self.showStatus(String(
                        format: NSLocalizedString("匹配完成：成功匹配 %d 个文件", comment: ""),
                        summary.matchedCount
                    ))
                }
                self.reloadData()
            }
        )
    }

    // MARK: Playback

    private func play(files: [LocalLibraryFile], start: LocalLibraryFile) {
        guard start.id > 0 else { return }
        guard let folder = folders.first(where: { $0.id == start.folderId }) else {
            showStatus(NSLocalizedString("找不到该文件所属的媒体库文件夹", comment: ""), isError: true)
            return
        }

        // 播放前只检查当前文件；不要在主线程对整页文件做 fileExists。
        guard LocalLibraryFolderAccess.shared.ensureAccess(folder: folder) else {
            presentFileAccessAlert(for: start, folder: folder)
            return
        }

        guard FileManager.default.fileExists(atPath: start.path) else {
            _ = try? store?.setMissing(fileId: start.id, isMissing: true)
            showStatus(
                String(format: NSLocalizedString("文件不存在或已移动：%@", comment: ""), start.path),
                isError: true
            )
            reloadData()
            return
        }

        let playableFiles = files.filter { !$0.isMissing && $0.id > 0 }
        guard let startIndex = playableFiles.firstIndex(where: { $0.id == start.id }) else {
            showStatus(NSLocalizedString("文件已缺失，无法播放。", comment: ""), isError: true)
            return
        }

        let playable = playableFiles.map { LocalFile(with: $0.fileURL) }
        onPlayFiles?(playable, playable[startIndex])
    }

    private func presentFileAccessAlert(for file: LocalLibraryFile, folder: LocalLibraryFolder) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("无法访问视频文件", comment: "")
        alert.informativeText = String(
            format: NSLocalizedString(
                "%@\n\n文件夹「%@」的访问权限可能已失效。重新选择文件夹即可更新授权。",
                comment: ""
            ),
            file.path,
            folder.name
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("重新选择文件夹…", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.rechooseFolder(folder)
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    // MARK: Helpers

    fileprivate static func makeLabel(
        _ text: String,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment = .left
    ) -> Label {
        let label = Label(labelWithString: text)
        label.font = font
        label.textColor = color
        label.alignment = alignment
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}

// MARK: - Search

extension LocalLibraryViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        searchWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.reloadData()
        }
        searchWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }
}

// MARK: - Collection view

extension LocalLibraryViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        cards.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let cell = collectionView.dequeueItem(class: LocalLibraryCollectionViewCell.self, for: indexPath)
        guard indexPath.item < cards.count else { return cell }
        let card = cards[indexPath.item]
        cell.update(with: card, provider: thumbnailProvider)
        switch card {
        case .group(let group):
            cell.view.setAccessibilityIdentifier("\(AccessibilityID.LocalLibrary.groupPrefix)\(group.animeId)")
            cell.view.setAccessibilityLabel(
                "\(group.animeTitle)，\(group.episodeCount) 集，\(group.sizeText)"
            )
        case .file(let file):
            cell.view.setAccessibilityIdentifier("\(AccessibilityID.LocalLibrary.itemPrefix)\(file.id)")
            cell.view.setAccessibilityLabel(
                "\(file.displayTitle)，\(file.displayEpisodeTitle)，\(file.matchStatusText)"
            )
        }
        return cell
    }
}

extension LocalLibraryViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        syncSelection()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        syncSelection()
    }

    private func syncSelection() {
        selectedCardIds = Set(collectionView.selectionIndexPaths.compactMap { indexPath in
            guard indexPath.item >= 0, indexPath.item < cards.count else { return nil }
            return cards[indexPath.item].id
        })
        updateBottomInfo()
        updateActionAvailability()
    }
}

extension LocalLibraryViewController: WaterfallLayoutDelegate {
    func waterfallLayout(
        _ layout: WaterfallLayout,
        heightForItemAt indexPath: IndexPath,
        itemWidth: CGFloat
    ) -> CGFloat {
        LocalLibraryCollectionViewCell.estimatedHeight(for: itemWidth)
    }
}

// MARK: - Collection view

private final class LocalLibraryCollectionView: CollectionView {

    var onDoubleClick: ((IndexPath) -> Void)?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let indexPath = indexPathForItem(at: point)
        super.mouseDown(with: event)
        if event.clickCount == 2, let indexPath {
            onDoubleClick?(indexPath)
        }
    }
}

// MARK: - Folder row

private final class LocalLibraryFolderRowView: NSView {

    var onSelect: (() -> Void)?
    var onRemove: (() -> Void)?

    var isSelectedRow = false {
        didSet { updateAppearance() }
    }

    private let titleLabel: Label
    private let countLabel: Label
    private let removeButton: NSButton?

    init(title: String, count: Int, identifier: String, canRemove: Bool) {
        self.titleLabel = Label(labelWithString: title)
        self.countLabel = Label(labelWithString: "\(count)")
        if canRemove {
            let button = NSButton(
                image: NSImage.safeSystemSymbol("xmark.circle.fill"),
                target: nil,
                action: nil
            )
            button.isBordered = false
            button.bezelStyle = .inline
            button.contentTintColor = .tertiaryLabelColor
            button.toolTip = NSLocalizedString("移除文件夹", comment: "")
            self.removeButton = button
        } else {
            self.removeButton = nil
        }
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityIdentifier(identifier)
        setAccessibilityLabel("\(title)，\(count) 个视频")

        titleLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        countLabel.font = .systemFont(ofSize: 10.5)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .right

        addSubview(titleLabel)
        addSubview(countLabel)
        if let removeButton {
            removeButton.target = self
            removeButton.action = #selector(removeClicked)
            addSubview(removeButton)
            // 始终保留占位，避免悬停/选中时文字跳动。
            countLabel.isHidden = false
            removeButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-6)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(18)
            }
            countLabel.snp.makeConstraints { make in
                make.trailing.equalTo(removeButton.snp.leading).offset(-6)
                make.centerY.equalToSuperview()
                make.width.greaterThanOrEqualTo(20)
            }
        } else {
            countLabel.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-10)
                make.centerY.equalToSuperview()
                make.width.greaterThanOrEqualTo(20)
            }
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.trailing.lessThanOrEqualTo(countLabel.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
        }
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        if let removeButton, !removeButton.isHidden {
            if let hit = removeButton.hitTest(local) {
                return hit
            }
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }

    override func accessibilityPerformPress() -> Bool {
        onSelect?()
        return true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    @objc private func removeClicked() {
        onRemove?()
    }

    private func updateAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self else { return }
            if self.isSelectedRow {
                self.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
                self.layer?.borderWidth = 1
                self.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
            } else {
                self.layer?.backgroundColor = NSColor.clear.cgColor
                self.layer?.borderWidth = 0
                self.layer?.borderColor = nil
            }
        }
        titleLabel.textColor = .labelColor
        countLabel.textColor = .secondaryLabelColor
    }
}

// MARK: - Poster cell

private final class LocalLibraryCollectionViewCell: CollectionViewItem {

    static func estimatedHeight(for width: CGFloat) -> CGFloat {
        return ceil(width * 1.4 + 82)
    }

    private let posterContainer = NSView()
    private let posterView = ImageView()
    private let placeholderView = NSView()
    private let placeholderIcon = ImageView()
    private let placeholderExtension: Label
    private let badge = Label(labelWithString: "")
    private let titleLabel: Label
    private let subtitleLabel: Label
    private let infoLabel: Label

    private weak var provider: LocalLibraryThumbnailProvider?
    private var thumbnailToken: UUID?
    private var cardID: String?
    private var infoPrefix = ""

    override var isSelected: Bool {
        didSet { updateSelectionAppearance() }
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        placeholderExtension = Label(labelWithString: "")
        titleLabel = Label(labelWithString: "")
        subtitleLabel = Label(labelWithString: "")
        infoLabel = Label(labelWithString: "")
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if let thumbnailToken {
            provider?.cancel(thumbnailToken)
        }
        thumbnailToken = nil
        thumbnailGeneration += 1
        posterView.kf.cancelDownloadTask()
        posterView.image = nil
        cardID = nil
        view.toolTip = nil
    }

    private func setup() {
        posterContainer.wantsLayer = true
        posterContainer.layer?.cornerRadius = 7
        posterContainer.layer?.cornerCurve = .continuous
        posterContainer.layer?.masksToBounds = true
        posterContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.18).cgColor

        posterView.setScaling(.aspectFill)
        posterView.wantsLayer = true
        posterView.layer?.masksToBounds = true

        placeholderView.wantsLayer = true
        placeholderView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        placeholderIcon.image = NSImage.safeSystemSymbol("film")
        placeholderIcon.contentTintColor = .tertiaryLabelColor
        placeholderIcon.setScaling(.aspectFit)

        placeholderExtension.font = .systemFont(ofSize: 10, weight: .semibold)
        placeholderExtension.textColor = .secondaryLabelColor
        placeholderExtension.alignment = .center

        badge.font = .systemFont(ofSize: 9.5, weight: .bold)
        badge.alignment = .center
        badge.textColor = .white
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 4
        badge.layer?.cornerCurve = .continuous
        badge.layer?.masksToBounds = true

        titleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.wraps = true
        titleLabel.cell?.isScrollable = false

        subtitleLabel.font = .systemFont(ofSize: 10.5)
        subtitleLabel.textColor = .secondaryLabelColor

        infoLabel.font = .systemFont(ofSize: 10)
        infoLabel.textColor = .tertiaryLabelColor
        infoLabel.lineBreakMode = .byTruncatingTail

        view.addSubview(posterContainer)
        posterContainer.addSubview(placeholderView)
        placeholderView.addSubview(placeholderIcon)
        placeholderView.addSubview(placeholderExtension)
        posterContainer.addSubview(posterView)
        posterContainer.addSubview(badge)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(infoLabel)

        // 显式绑定父视图，避免集合视图复用/重建时视图尚未挂载导致
        // SnapKit `equalToSuperview` 的 fatalError（本地媒体库曾因此闪退）。
        posterContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(view)
            make.height.equalTo(posterContainer.snp.width).multipliedBy(1.4)
        }
        placeholderView.snp.makeConstraints { make in
            make.edges.equalTo(posterContainer)
        }
        posterView.snp.makeConstraints { make in
            make.edges.equalTo(posterContainer)
        }
        placeholderIcon.snp.makeConstraints { make in
            make.centerX.equalTo(placeholderView)
            make.centerY.equalTo(placeholderView).offset(-8)
            make.width.height.equalTo(34)
        }
        placeholderExtension.snp.makeConstraints { make in
            make.centerX.equalTo(placeholderView)
            make.top.equalTo(placeholderIcon.snp.bottom).offset(6)
            make.leading.trailing.equalTo(placeholderView).inset(6)
        }
        badge.snp.makeConstraints { make in
            make.leading.equalTo(posterContainer).offset(6)
            make.bottom.equalTo(posterContainer).offset(-6)
            make.height.equalTo(17)
            make.width.greaterThanOrEqualTo(44)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(posterContainer.snp.bottom).offset(6)
            make.leading.trailing.equalTo(view).inset(1)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.leading.trailing.equalTo(view).inset(1)
        }
        infoLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(3)
            make.leading.trailing.equalTo(view).inset(1)
            make.bottom.lessThanOrEqualTo(view)
        }
        updateSelectionAppearance()
    }

    func update(with card: LocalLibraryCard, provider: LocalLibraryThumbnailProvider) {
        self.provider = provider
        cardID = card.id

        if let thumbnailToken {
            provider.cancel(thumbnailToken)
        }
        thumbnailToken = nil
        thumbnailGeneration += 1
        posterView.kf.cancelDownloadTask()
        posterView.image = nil
        titleLabel.textColor = .labelColor
        subtitleLabel.textColor = .secondaryLabelColor
        posterContainer.alphaValue = 1
        placeholderExtension.isHidden = false
        placeholderView.isHidden = false

        switch card {
        case .group(let group):
            configureGroup(group, provider: provider)
        case .file(let file):
            configureFile(file, provider: provider)
        }
        updateSelectionAppearance()
    }

    private func configureFile(_ file: LocalLibraryFile, provider: LocalLibraryThumbnailProvider) {
        placeholderExtension.stringValue = file.fileExtension
        titleLabel.stringValue = file.displayTitle
        subtitleLabel.stringValue = file.displayEpisodeTitle
        infoPrefix = "\(file.sizeText)"
        infoLabel.stringValue = composeInfo(file.mediaMetadata)
        view.toolTip = file.path

        if file.isMissing {
            badge.stringValue = NSLocalizedString("缺失", comment: "")
            badge.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.82).cgColor
            placeholderIcon.image = NSImage.safeSystemSymbol("exclamationmark.triangle")
            posterContainer.alphaValue = 0.55
            titleLabel.textColor = .secondaryLabelColor
            subtitleLabel.textColor = .tertiaryLabelColor
            return
        }

        if file.isMatched {
            badge.stringValue = NSLocalizedString("已匹配", comment: "")
            badge.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.82).cgColor
            placeholderIcon.image = NSImage.safeSystemSymbol("sparkles.tv")
        } else {
            badge.stringValue = NSLocalizedString("未匹配", comment: "")
            badge.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.82).cgColor
            placeholderIcon.image = NSImage.safeSystemSymbol("film")
        }

        if let url = file.displayImageURL {
            posterView.kf.setImage(with: url)
        }
        requestThumbnail(for: file, provider: provider)
    }

    private func configureGroup(_ group: LocalLibraryAnimeGroup, provider: LocalLibraryThumbnailProvider) {
        let primary = group.primaryFile
        placeholderExtension.stringValue = primary?.fileExtension ?? "VIDEO"
        titleLabel.stringValue = group.animeTitle
        subtitleLabel.stringValue = String(
            format: NSLocalizedString("%d 集 · %@", comment: ""),
            group.episodeCount,
            group.sizeText
        )
        infoPrefix = ""
        infoLabel.stringValue = group.mediaMetadata.displayText
        view.toolTip = primary?.path

        if group.missingCount > 0 {
            badge.stringValue = String(
                format: NSLocalizedString("缺失 %d", comment: ""),
                group.missingCount
            )
            badge.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.82).cgColor
            posterContainer.alphaValue = 0.72
        } else {
            badge.stringValue = NSLocalizedString("剧集", comment: "")
            badge.layer?.backgroundColor = NSColor.systemTeal.withAlphaComponent(0.82).cgColor
        }
        placeholderIcon.image = NSImage.safeSystemSymbol("film.stack")

        if let url = group.displayImageURL {
            posterView.kf.setImage(with: url)
        }
        if let primary, !primary.isMissing {
            requestThumbnail(for: primary, provider: provider)
        }
    }

    private var thumbnailGeneration = 0

    private func requestThumbnail(for file: LocalLibraryFile, provider: LocalLibraryThumbnailProvider) {
        thumbnailGeneration += 1
        let generation = thumbnailGeneration
        let expectedCardID = cardID
        let token = provider.request(for: file) { [weak self] result in
            guard let self,
                  self.thumbnailGeneration == generation,
                  self.cardID == expectedCardID else { return }
            if let image = result.image {
                self.posterView.kf.cancelDownloadTask()
                self.posterView.image = image
            }
            self.infoLabel.stringValue = self.composeInfo(result.metadata)
        }
        thumbnailToken = token
    }

    private func composeInfo(_ metadata: LocalLibraryMediaMetadata) -> String {
        var parts: [String] = []
        if !infoPrefix.isEmpty {
            parts.append(infoPrefix)
        }
        if !metadata.isEmpty {
            parts.append(metadata.displayText)
        }
        return parts.joined(separator: " · ")
    }

    private func updateSelectionAppearance() {
        posterContainer.layer?.borderWidth = isSelected ? 2 : 0
        posterContainer.layer?.borderColor = isSelected
            ? NSColor.controlAccentColor.cgColor
            : nil
    }
}

// MARK: - Empty state

private final class LocalLibraryEmptyStateView: NSView {

    private let iconView = ImageView()
    private let titleLabel = LocalLibraryViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 15, weight: .semibold),
        color: .labelColor,
        alignment: .center
    )
    private let detailLabel = LocalLibraryViewController.makeLabel(
        "",
        font: .systemFont(ofSize: 11.5),
        color: .secondaryLabelColor,
        alignment: .center
    )
    private let actionButton = NSButton(title: "", target: nil, action: nil)

    private var onAction: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        iconView.setScaling(.aspectFit)
        iconView.contentTintColor = .tertiaryLabelColor

        detailLabel.maximumNumberOfLines = 3
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.cell?.wraps = true
        detailLabel.cell?.isScrollable = false
        detailLabel.preferredMaxLayoutWidth = 360

        actionButton.bezelStyle = .rounded
        actionButton.target = self
        actionButton.action = #selector(actionClicked)
        actionButton.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.addFolder)
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
            make.top.greaterThanOrEqualToSuperview().offset(12)
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(42)
        }
    }

    func configure(
        symbolName: String,
        title: String,
        detail: String,
        actionTitle: String?,
        actionIdentifier: String? = nil,
        onAction: (() -> Void)?
    ) {
        iconView.image = NSImage.safeSystemSymbol(symbolName)
        titleLabel.stringValue = title
        detailLabel.stringValue = detail
        self.onAction = onAction
        if let actionTitle {
            actionButton.title = actionTitle
            actionButton.setAccessibilityIdentifier(
                actionIdentifier ?? AccessibilityID.LocalLibrary.addFolder
            )
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }
    }

    @objc private func actionClicked() {
        onAction?()
    }
}

// MARK: - Flipped view

private final class LocalLibraryFlippedView: NSView {
    override var isFlipped: Bool { true }
}
