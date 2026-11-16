//
//  TrendingViewController.swift
//  AniXPlayer
//
//  macOS：排行榜（全站热播 / 全站飙升 / 新番热播）。
//

import Cocoa
import SnapKit

final class TrendingViewController: ViewController {

    private var mode: TrendingMetricMode = .hot
    private var period = "week"
    private var scope = "current-season"
    private var items: [TrendingItem] = []
    private var refreshTask: Task<Void, Never>?

    private lazy var categoryControl: NSSegmentedControl = {
        let control = NSSegmentedControl(
            labels: [
                NSLocalizedString("全站热播", comment: ""),
                NSLocalizedString("全站飙升", comment: ""),
                NSLocalizedString("新番热播", comment: ""),
            ],
            trackingMode: .selectOne,
            target: self,
            action: #selector(categoryChanged)
        )
        control.selectedSegment = 0
        control.segmentStyle = .texturedRounded
        control.setAccessibilityIdentifier(AccessibilityID.Trending.categoryControl)
        return control
    }()

    private lazy var periodPopup: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.addItems(withTitles: [
            NSLocalizedString("最近一周", comment: ""),
            NSLocalizedString("最近一月", comment: ""),
            NSLocalizedString("最近一季度", comment: ""),
        ])
        popup.item(at: 0)?.representedObject = "week"
        popup.item(at: 1)?.representedObject = "month"
        popup.item(at: 2)?.representedObject = "quarter"
        popup.selectItem(at: 0)
        popup.target = self
        popup.action = #selector(periodChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.Trending.periodPopup)
        return popup
    }()

    private lazy var scopePopup: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.addItems(withTitles: [
            NSLocalizedString("本季新番", comment: ""),
            NSLocalizedString("上季新番", comment: ""),
        ])
        popup.item(at: 0)?.representedObject = "current-season"
        popup.item(at: 1)?.representedObject = "previous-season"
        popup.selectItem(at: 0)
        popup.target = self
        popup.action = #selector(scopeChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.Trending.scopePopup)
        popup.isHidden = true
        return popup
    }()

    private lazy var refreshButton: Button = {
        let button = Button(title: NSLocalizedString("刷新", comment: ""), target: self, action: #selector(refresh))
        button.setAccessibilityIdentifier(AccessibilityID.Trending.refreshButton)
        return button
    }()

    private lazy var summaryLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.lineBreakMode = .byTruncatingTail
        label.setAccessibilityIdentifier(AccessibilityID.Trending.summaryLabel)
        return label
    }()

    private lazy var statusLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_normal()
        label.textColor = .subtitleTextColor
        label.alignment = .center
        label.maximumNumberOfLines = 3
        label.setAccessibilityIdentifier(AccessibilityID.Trending.statusLabel)
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
        cv.registerItem(class: TrendingCollectionViewCell.self)
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.clear]
        cv.isSelectable = true
        cv.setAccessibilityIdentifier(AccessibilityID.Trending.list)
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
        title = NSLocalizedString("排行榜", comment: "")
        view.setAccessibilityIdentifier(AccessibilityID.Trending.root)

        let controls = NSStackView(views: [categoryControl, periodPopup, scopePopup, NSView(), refreshButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY

        view.addSubview(controls)
        view.addSubview(summaryLabel)
        view.addSubview(scrollView)
        view.addSubview(statusLabel)

        controls.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }

        summaryLabel.snp.makeConstraints { make in
            make.top.equalTo(controls.snp.bottom).offset(6)
            make.leading.trailing.equalTo(controls)
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(summaryLabel.snp.bottom).offset(4)
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
        let contentHeight = max(collectionView.collectionViewLayout?.collectionViewContentSize.height ?? 0, bounds.height)
        if collectionView.frame.width != bounds.width || collectionView.frame.height != contentHeight {
            collectionView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: contentHeight)
            collectionView.collectionViewLayout?.invalidateLayout()
        }
    }

    // MARK: - Actions

    @objc private func categoryChanged() {
        switch categoryControl.selectedSegment {
        case 1:
            mode = .rising
        case 2:
            mode = .newAnime
        default:
            mode = .hot
        }
        let isNewAnime = mode == .newAnime
        periodPopup.isHidden = isNewAnime
        scopePopup.isHidden = !isNewAnime
        startRefresh()
    }

    @objc private func periodChanged() {
        period = periodPopup.selectedItem?.representedObject as? String ?? "week"
        if mode != .newAnime {
            startRefresh()
        }
    }

    @objc private func scopeChanged() {
        scope = scopePopup.selectedItem?.representedObject as? String ?? "current-season"
        if mode == .newAnime {
            startRefresh()
        }
    }

    @objc private func refresh() {
        startRefresh()
    }

    // MARK: - Data

    private func startRefresh() {
        refreshTask?.cancel()
        statusLabel.isHidden = false
        statusLabel.text = NSLocalizedString("正在加载排行榜…", comment: "")
        collectionView.isHidden = true

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                self.statusLabel.text = NSLocalizedString("登录后才能查看排行榜", comment: "")
                return
            }

            do {
                let response = try await TrendingNetworkHandle.fetch(
                    mode: self.mode,
                    period: self.period,
                    scope: self.scope
                )
                guard !Task.isCancelled else { return }

                self.items = response.bangumiList
                self.updateSummary(response.summary)
                self.collectionView.reloadData()
                self.collectionView.isHidden = self.items.isEmpty
                self.statusLabel.isHidden = !self.items.isEmpty
                self.statusLabel.text = self.items.isEmpty
                    ? NSLocalizedString("暂无排行榜数据", comment: "")
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

    private func updateSummary(_ summary: TrendingSummary?) {
        guard let summary else {
            summaryLabel.text = ""
            return
        }
        let range: String
        if !summary.dateFrom.isEmpty || !summary.dateTo.isEmpty {
            range = " · " + summary.dateFrom + " ~ " + summary.dateTo
        } else {
            range = ""
        }
        summaryLabel.text = (summary.title.isEmpty ? summary.rankingType : summary.title) + range
    }

    private func changeFavorite(animeId: Int, isLiked: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLiked) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Collection view

extension TrendingViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.dequeueItem(class: TrendingCollectionViewCell.self, for: indexPath)
        guard indexPath.item < items.count else { return cell }
        let item = items[indexPath.item]
        cell.update(trending: item, mode: mode)
        cell.onFavoriteToggle = { [weak self] animeId, isLiked in
            guard let self else { return }
            Task { @MainActor in
                guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else { return }
                do {
                    try await self.changeFavorite(animeId: animeId, isLiked: isLiked)
                    item.isFavorited = isLiked
                    self.collectionView.reloadData()
                } catch {
                    self.view.show(error: error)
                    self.collectionView.reloadData()
                }
            }
        }
        return cell
    }
}

extension TrendingViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first, indexPath.item < items.count else { return }
        collectionView.deselectItems(at: indexPaths)
        let item = items[indexPath.item]
        let vc = BangumiDetailViewController(animateId: item.animeId)
        navigator?.pushViewController(vc)
    }
}

extension TrendingViewController: WaterfallLayoutDelegate {
    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        TrendingCollectionViewCell.estimatedHeight(for: itemWidth)
    }
}
