//
//  PlayHistoryWindow.swift
//  AniXPlayer
//
//  macOS：播放历史窗口。
//

import Cocoa
import SnapKit
import Kingfisher

final class PlayHistoryItem: AnimeListItem {
    let anime: PlayHistoryAnime

    init(anime: PlayHistoryAnime) {
        self.anime = anime
    }

    var animeId: Int { anime.animeId }
    var animeTitle: String { anime.animeTitle }
    var imageUrl: String { anime.imageUrl }
    var rating: Double { 0 }
    var typeDescription: String { anime.typeDescription }
    var isOnAir: Bool { anime.isOnAir }
    var isFavorited: Bool { false }

    var lastWatched: Date? {
        anime.episodes.compactMap(\.lastWatched).max()
    }

    var episodeText: String {
        if anime.episodes.isEmpty {
            return NSLocalizedString("暂无剧集记录", comment: "")
        }
        return String(
            format: NSLocalizedString("看过 %d 集", comment: ""),
            anime.episodes.count
        )
    }
}

final class PlayHistoryCollectionViewCell: CollectionViewItem {
    static func estimatedHeight(for width: CGFloat) -> CGFloat {
        return width * 1.4 + 72
    }

    private lazy var posterView: ImageView = {
        let view = ImageView()
        view.setScaling(.aspectFit)
        view.wantsLayer = true
        view.layer?.cornerRadius = 6
        view.layer?.masksToBounds = true
        return view
    }()

    private lazy var titleLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_normal()
        label.textColor = .textColor
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var detailLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var timeLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        return label
    }()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let infoStack = NSStackView(views: [titleLabel, detailLabel, timeLabel])
        infoStack.orientation = .vertical
        infoStack.spacing = 3
        infoStack.alignment = .leading

        let root = NSStackView(views: [posterView, infoStack])
        root.orientation = .vertical
        root.spacing = 8
        // 让海报与文字撑满瀑布流列宽；否则低分辨率海报会按 intrinsic width 缩成一小块。
        root.alignment = .width

        view.addSubview(root)
        root.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        posterView.snp.makeConstraints { make in
            make.height.equalTo(posterView.snp.width).multipliedBy(1.4)
        }
    }

    func update(item: PlayHistoryItem, dateFormatter: DateFormatter) {
        if let url = URL(string: item.imageUrl) {
            posterView.kf.setImage(with: url)
        } else {
            posterView.image = nil
        }
        titleLabel.text = item.animeTitle
        detailLabel.text = item.episodeText
        if let date = item.lastWatched {
            timeLabel.text = dateFormatter.string(from: date)
        } else {
            timeLabel.text = ""
        }
    }
}

final class PlayHistoryViewController: ViewController {

    /// 由 MainShell 注入：打开作品详情（不占用 navigator）。
    var onOpenDetail: ((Int) -> Void)?

    private var items: [PlayHistoryItem] = []
    private var refreshTask: Task<Void, Never>?

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

    private lazy var layout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 4
        layout.itemPadding = 12
        layout.sectionInset = NSEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
        layout.delegate = self
        return layout
    }()

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = layout
        cv.registerItem(class: PlayHistoryCollectionViewCell.self)
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.clear]
        cv.isSelectable = true
        cv.setAccessibilityIdentifier(AccessibilityID.History.list)
        return cv
    }()

    private lazy var scrollView: ScrollView<CollectionView> = {
        let sv = ScrollView<CollectionView>()
        sv.containerView = collectionView
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.drawsBackground = false
        return sv
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
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
        let bounds = scrollView.contentView.bounds
        let height = max(collectionView.collectionViewLayout?.collectionViewContentSize.height ?? 0, bounds.height)
        if collectionView.frame.width != bounds.width || collectionView.frame.height != height {
            collectionView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: height)
            collectionView.collectionViewLayout?.invalidateLayout()
        }
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

    private func startRefresh() {
        refreshTask?.cancel()
        statusLabel.isHidden = false
        statusLabel.text = NSLocalizedString("正在加载播放历史…", comment: "")
        collectionView.isHidden = true

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                self.statusLabel.text = NSLocalizedString("登录后才能查看播放历史", comment: "")
                return
            }

            do {
                let response = try await PlayHistoryNetworkHandle.fetch()
                guard !Task.isCancelled else { return }
                self.items = response.animes
                    .sorted { ($0.episodes.compactMap(\.lastWatched).max() ?? .distantPast) > ($1.episodes.compactMap(\.lastWatched).max() ?? .distantPast) }
                    .map(PlayHistoryItem.init)
                self.collectionView.reloadData()
                self.collectionView.isHidden = self.items.isEmpty
                self.statusLabel.isHidden = !self.items.isEmpty
                self.statusLabel.text = self.items.isEmpty
                    ? NSLocalizedString("还没有播放历史", comment: "")
                    : ""
                self.viewDidLayout()
            } catch {
                guard !Task.isCancelled else { return }
                self.items = []
                self.collectionView.reloadData()
                self.collectionView.isHidden = true
                self.statusLabel.isHidden = false
                self.statusLabel.text = error.localizedDescription
            }
        }
    }
}

extension PlayHistoryViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.dequeueItem(class: PlayHistoryCollectionViewCell.self, for: indexPath)
        guard indexPath.item < items.count else { return cell }
        cell.update(item: items[indexPath.item], dateFormatter: dateFormatter)
        return cell
    }
}

extension PlayHistoryViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first, indexPath.item < items.count else { return }
        collectionView.deselectItems(at: indexPaths)
        let item = items[indexPath.item]
        if let onOpenDetail = onOpenDetail {
            onOpenDetail(item.animeId)
        } else {
            navigator?.pushViewController(BangumiDetailViewController(animateId: item.animeId))
        }
    }
}

extension PlayHistoryViewController: WaterfallLayoutDelegate {
    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        PlayHistoryCollectionViewCell.estimatedHeight(for: itemWidth)
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
