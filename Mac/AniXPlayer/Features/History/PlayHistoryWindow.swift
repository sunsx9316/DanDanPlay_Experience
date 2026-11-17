//
//  PlayHistoryWindow.swift
//  AniXPlayer
//
//  macOS：播放历史窗口。
//

import Cocoa
import SnapKit
import Kingfisher

struct PlayHistoryItem {
    let anime: PlayHistoryAnime

    var animeId: Int { anime.animeId }
    var animeTitle: String { anime.animeTitle }
    var imageUrl: String { anime.imageUrl }
    var episodes: [PlayHistoryEpisode] { anime.episodes }

    var lastWatched: Date? {
        anime.episodes.compactMap(\.lastWatched).max()
    }
}

final class PlayHistoryViewController: ViewController {

    /// 由 MainShell 注入：打开作品详情（不占用 navigator）。
    var onOpenDetail: ((Int) -> Void)?

    private var items: [PlayHistoryItem] = []
    private var refreshTask: Task<Void, Never>?
    private var referenceDate = Date()
    private var lastTableWidth: CGFloat = 0
    private var lastOpenTime: TimeInterval = 0
    private var lastOpenAnimeId: Int?

    private lazy var titleLabel: Label = {
        let label = Label(labelWithString: NSLocalizedString("播放历史", comment: ""))
        label.font = .ddp_large(weight: .bold)
        label.textColor = .textColor
        return label
    }()

    private lazy var refreshButton: Button = {
        let button = Button(title: NSLocalizedString("刷新", comment: ""), target: self, action: #selector(refresh))
        button.setAccessibilityIdentifier(AccessibilityID.History.refreshButton)
        return button
    }()

    private lazy var statusLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_normal()
        label.textColor = .subtitleTextColor
        label.alignment = .center
        label.maximumNumberOfLines = 3
        label.setAccessibilityIdentifier(AccessibilityID.History.statusLabel)
        return label
    }()

    private lazy var tableView: TableView = {
        let tv = TableView()
        tv.dataSource = self
        tv.delegate = self
        tv.backgroundColor = .clear
        tv.headerView = nil
        tv.rowSizeStyle = .custom
        tv.rowHeight = PlayHistoryRowLayout.minimumHeight
        tv.usesAutomaticRowHeights = false
        tv.selectionHighlightStyle = .regular
        tv.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tv.autoresizingMask = [.width]
        tv.intercellSpacing = NSSize(width: 0, height: 0)
        tv.registerClassCell(class: PlayHistoryRowView.self)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("history"))
        column.resizingMask = .autoresizingMask
        tv.addTableColumn(column)

        tv.target = self
        tv.action = #selector(handleRowClick)
        tv.setAccessibilityIdentifier(AccessibilityID.History.list)
        tv.enableRowHoverTracking()
        return tv
    }()

    private lazy var scrollView: ScrollView<TableView> = {
        let sv = ScrollView<TableView>()
        sv.containerView = tableView
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers = true
        sv.horizontalScrollElasticity = .none
        sv.borderType = .noBorder
        sv.drawsBackground = false
        return sv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("播放历史", comment: "")
        view.setAccessibilityIdentifier(AccessibilityID.History.root)

        let header = NSStackView(views: [titleLabel, NSView(), refreshButton])
        header.orientation = .horizontal
        header.alignment = .centerY

        view.addSubview(header)
        view.addSubview(scrollView)
        view.addSubview(statusLabel)

        header.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
        statusLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }

        startRefresh()
    }

    deinit {
        refreshTask?.cancel()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        let width = tableView.bounds.width
        guard width > 0, abs(width - lastTableWidth) > 0.5 else { return }
        lastTableWidth = width
        guard !items.isEmpty else { return }
        tableView.reloadData()
    }

    /// 主窗口「我的 → 播放历史」每次切回时刷新；独立窗口仍由刷新按钮触发。
    func refreshContent() {
        guard isViewLoaded else {
            _ = view
            return
        }
        startRefresh()
    }

    @objc private func refresh() {
        startRefresh()
    }

    @objc private func handleRowClick() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        openDetail(at: row)
    }

    private func openDetail(at row: Int) {
        guard row >= 0, row < items.count else { return }
        let item = items[row]

        let now = ProcessInfo.processInfo.systemUptime
        let isDuplicateClick = lastOpenAnimeId == item.animeId && now - lastOpenTime < 0.35
        lastOpenTime = now
        lastOpenAnimeId = item.animeId
        tableView.deselectAll(nil)
        guard !isDuplicateClick else { return }

        if let onOpenDetail = onOpenDetail {
            onOpenDetail(item.animeId)
        } else {
            navigator?.pushViewController(BangumiDetailViewController(animateId: item.animeId))
        }
    }

    private func startRefresh() {
        refreshTask?.cancel()
        statusLabel.isHidden = false
        statusLabel.text = NSLocalizedString("正在加载播放历史…", comment: "")
        tableView.isHidden = true

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                guard !Task.isCancelled else { return }
                self.statusLabel.text = NSLocalizedString("登录后才能查看播放历史", comment: "")
                return
            }

            do {
                let response = try await PlayHistoryNetworkHandle.fetch()
                guard !Task.isCancelled else { return }
                self.referenceDate = Date()
                self.items = response.animes
                    .sorted { ($0.episodes.compactMap(\.lastWatched).max() ?? .distantPast) > ($1.episodes.compactMap(\.lastWatched).max() ?? .distantPast) }
                    .map(PlayHistoryItem.init(anime:))
                self.tableView.reloadData()
                self.tableView.isHidden = self.items.isEmpty
                self.statusLabel.isHidden = !self.items.isEmpty
                self.statusLabel.text = self.items.isEmpty
                    ? NSLocalizedString("还没有播放历史", comment: "")
                    : ""
            } catch {
                guard !Task.isCancelled else { return }
                self.items = []
                self.tableView.reloadData()
                self.tableView.isHidden = true
                self.statusLabel.isHidden = false
                self.statusLabel.text = error.localizedDescription
            }
        }
    }
}

extension PlayHistoryViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }
}

extension PlayHistoryViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < items.count else { return nil }
        let cell = tableView.dequeueReusableCell(class: PlayHistoryRowView.self)
        cell.onActivate = { [weak self] in
            self?.openDetail(at: row)
        }
        cell.update(
            item: items[row],
            now: referenceDate,
            width: max(tableView.bounds.width, 320)
        )
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row >= 0, row < items.count else { return PlayHistoryRowLayout.minimumHeight }
        return PlayHistoryRowView.height(
            for: items[row],
            width: max(tableView.bounds.width, 320)
        )
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        tableView.themedRowView(forRow: row)
    }
}

final class PlayHistoryNavigationWindowController: NavigationWindowController {
    init() {
        let config = NavigationConfiguration(
            windowSize: NSSize(width: 900, height: 640),
            defaultTitle: NSLocalizedString("播放历史", comment: ""),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            hasToolbar: true,
            fixedContentSize: false
        )
        super.init(rootViewController: PlayHistoryViewController(), config: config)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
