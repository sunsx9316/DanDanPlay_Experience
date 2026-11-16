//
//  BangumiQueueViewController.swift
//  AniXPlayer
//
//  macOS：我的追番 / 未看番剧窗口。
//

import Cocoa
import SnapKit
import Kingfisher

final class BangumiQueueDetailCollectionViewCell: CollectionViewItem {
    static func estimatedHeight(forWidth width: CGFloat) -> CGFloat {
        return width * 1.4 + 66
    }

    private lazy var posterView: ImageView = {
        let view = ImageView()
        view.setScaling(.aspectFill)
        view.wantsLayer = true
        view.layer?.cornerRadius = 6
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.placeholderColor.cgColor
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

    private lazy var episodeLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var timeLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .mainColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(posterView)
        view.addSubview(titleLabel)
        view.addSubview(episodeLabel)
        view.addSubview(timeLabel)

        posterView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(posterView.snp.width).multipliedBy(1.4)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(posterView.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview()
        }

        episodeLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(3)
            make.leading.trailing.equalToSuperview()
        }

        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(episodeLabel.snp.bottom).offset(3)
            make.leading.trailing.equalToSuperview()
        }
    }

    func configure(with item: BangumiQueueDetails) {
        view.setAccessibilityIdentifier(AccessibilityID.Queue.itemPrefix + "\(item.animeId)")

        if let url = URL(string: item.imageUrl), !item.imageUrl.isEmpty {
            posterView.kf.setImage(with: url)
        } else {
            posterView.image = nil
        }

        titleLabel.text = item.animeTitle

        if let latestEpisode = item.latestEpisode {
            if item.episodes.count > 1 {
                episodeLabel.text = String(
                    format: NSLocalizedString("%d 集未看 · %@", comment: ""),
                    item.episodes.count,
                    latestEpisode.episodeTitle
                )
            } else {
                episodeLabel.text = latestEpisode.episodeTitle
            }
        } else {
            episodeLabel.text = NSLocalizedString("尚未观看", comment: "")
        }

        if let lastWatched = item.lastWatched {
            timeLabel.text = String(
                format: NSLocalizedString("上次观看 %@", comment: ""),
                dateFormatter.string(from: lastWatched)
            )
        } else if let airDate = item.latestEpisode?.airDate {
            timeLabel.text = String(
                format: NSLocalizedString("更新 %@", comment: ""),
                dateFormatter.string(from: airDate)
            )
        } else {
            timeLabel.text = item.isOnAir
                ? NSLocalizedString("连载中", comment: "")
                : NSLocalizedString("已完结", comment: "")
        }
    }
}

final class BangumiQueueSectionHeaderView: NSView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("BangumiQueueSectionHeaderView")

    private lazy var titleLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_large(weight: .bold)
        label.textColor = .textColor
        return label
    }()

    private lazy var countLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleLabel)
        addSubview(countLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview().offset(-6)
        }
        countLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8)
            make.centerY.equalTo(titleLabel)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(kind: BangumiQueueSectionKind, count: Int) {
        let title: String
        let identifier: String
        switch kind {
        case .unwatched:
            title = NSLocalizedString("未看剧集", comment: "")
            identifier = AccessibilityID.Queue.sectionUnwatched
        case .followed:
            title = NSLocalizedString("已关注未看", comment: "")
            identifier = AccessibilityID.Queue.sectionFollowed
        }
        titleLabel.text = title
        countLabel.text = "\(count)"
        setAccessibilityIdentifier(identifier)
    }
}

final class BangumiQueueViewController: ViewController {

    private var sections: [BangumiQueueSectionModel] = []
    private var refreshTask: Task<Void, Never>?

    private lazy var titleLabel: Label = {
        let label = Label(labelWithString: NSLocalizedString("我的追番", comment: ""))
        label.font = .ddp_large(weight: .bold)
        label.textColor = .textColor
        return label
    }()

    private lazy var summaryLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var refreshButton: Button = {
        let button = Button(title: NSLocalizedString("刷新", comment: ""), target: self, action: #selector(refresh))
        button.setAccessibilityIdentifier(AccessibilityID.Queue.refreshButton)
        return button
    }()

    private lazy var statusLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_normal()
        label.textColor = .subtitleTextColor
        label.alignment = .center
        label.maximumNumberOfLines = 3
        label.setAccessibilityIdentifier(AccessibilityID.Queue.statusLabel)
        return label
    }()

    private lazy var layout: NSCollectionViewFlowLayout = {
        let layout = NSCollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        layout.sectionInset = NSEdgeInsets(top: 4, left: 16, bottom: 20, right: 16)
        layout.headerReferenceSize = NSSize(width: 100, height: 34)
        return layout
    }()

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = layout
        cv.registerItem(class: BangumiQueueDetailCollectionViewCell.self)
        cv.register(
            BangumiQueueSectionHeaderView.self,
            forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: BangumiQueueSectionHeaderView.reuseIdentifier
        )
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.clear]
        cv.isSelectable = true
        cv.setAccessibilityIdentifier(AccessibilityID.Queue.list)
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

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("我的追番", comment: "")
        view.setAccessibilityIdentifier(AccessibilityID.Queue.root)

        let header = NSStackView(views: [titleLabel, summaryLabel, NSView(), refreshButton])
        header.orientation = .horizontal
        header.spacing = 8
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
        guard bounds.width > 0 else { return }

        if collectionView.frame.width != bounds.width {
            collectionView.frame.size.width = bounds.width
            collectionView.collectionViewLayout?.invalidateLayout()
            collectionView.layoutSubtreeIfNeeded()
        }

        let contentHeight = max(
            collectionView.collectionViewLayout?.collectionViewContentSize.height ?? 0,
            bounds.height
        )
        if collectionView.frame.height != contentHeight {
            collectionView.frame.size.height = contentHeight
        }
    }

    @objc private func refresh() {
        startRefresh()
    }

    private func startRefresh() {
        refreshTask?.cancel()
        statusLabel.isHidden = false
        statusLabel.text = NSLocalizedString("正在加载追番队列…", comment: "")
        collectionView.isHidden = true

        refreshTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                self.sections = []
                self.collectionView.reloadData()
                self.statusLabel.isHidden = false
                self.statusLabel.text = NSLocalizedString("登录后才能查看我的追番", comment: "")
                self.summaryLabel.text = ""
                return
            }

            do {
                let response = try await BangumiQueueNetworkHandle.fetchDetails()
                guard !Task.isCancelled else { return }

                self.sections = BangumiQueueGrouping.sections(
                    watched: response.bangumiList,
                    unwatched: response.unwatchedBangumiList
                )
                self.collectionView.reloadData()
                self.collectionView.layoutSubtreeIfNeeded()

                let isEmpty = self.sections.isEmpty
                self.collectionView.isHidden = isEmpty
                self.statusLabel.isHidden = !isEmpty
                self.statusLabel.text = isEmpty
                    ? NSLocalizedString("暂无未看剧集", comment: "")
                    : ""
                self.summaryLabel.text = self.makeSummary()
                self.viewDidLayout()
            } catch {
                guard !Task.isCancelled else { return }
                self.sections = []
                self.collectionView.reloadData()
                self.collectionView.isHidden = true
                self.statusLabel.isHidden = false
                self.statusLabel.text = error.localizedDescription
                self.summaryLabel.text = ""
            }
        }
    }

    private func makeSummary() -> String {
        let unwatchedCount = sections.first { $0.kind == .unwatched }?.items.count ?? 0
        let followedCount = sections.first { $0.kind == .followed }?.items.count ?? 0
        return String(
            format: NSLocalizedString("未看 %d 部 · 已关注未看 %d 部", comment: ""),
            unwatchedCount,
            followedCount
        )
    }

    private func pushDetail(animeId: Int) {
        navigator?.pushViewController(BangumiDetailViewController(animateId: animeId))
    }
}

extension BangumiQueueViewController: NSCollectionViewDataSource {
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        sections.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard section < sections.count else { return 0 }
        return sections[section].items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.dequeueItem(class: BangumiQueueDetailCollectionViewCell.self, for: indexPath)
        guard indexPath.section < sections.count,
              indexPath.item < sections[indexPath.section].items.count else {
            return cell
        }
        cell.configure(with: sections[indexPath.section].items[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
        at indexPath: IndexPath
    ) -> NSView {
        guard kind == NSCollectionView.elementKindSectionHeader,
              indexPath.section < sections.count else {
            return NSView()
        }
        let view = collectionView.makeSupplementaryView(
            ofKind: kind,
            withIdentifier: BangumiQueueSectionHeaderView.reuseIdentifier,
            for: indexPath
        )
        let header = view as? BangumiQueueSectionHeaderView
        let section = sections[indexPath.section]
        header?.configure(kind: section.kind, count: section.items.count)
        return view
    }
}

extension BangumiQueueViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first,
              indexPath.section < sections.count,
              indexPath.item < sections[indexPath.section].items.count else { return }
        collectionView.deselectItems(at: indexPaths)
        pushDetail(animeId: sections[indexPath.section].items[indexPath.item].animeId)
    }
}

extension BangumiQueueViewController: NSCollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: NSCollectionView,
        layout collectionViewLayout: NSCollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> NSSize {
        let width = collectionView.bounds.width
        guard width > 0 else { return NSSize(width: 200, height: 346) }
        let availableWidth = width - 32 - 12 * 3
        let itemWidth = max(floor(availableWidth / 4), 120)
        return NSSize(
            width: itemWidth,
            height: BangumiQueueDetailCollectionViewCell.estimatedHeight(forWidth: itemWidth)
        )
    }
}

final class BangumiQueueNavigationWindowController: NavigationWindowController {
    init() {
        let config = NavigationConfiguration(
            windowSize: NSSize(width: 900, height: 640),
            defaultTitle: NSLocalizedString("我的追番", comment: ""),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            hasToolbar: true,
            fixedContentSize: false
        )
        super.init(rootViewController: BangumiQueueViewController(), config: config)
        window?.setAccessibilityIdentifier(AccessibilityID.Queue.window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
