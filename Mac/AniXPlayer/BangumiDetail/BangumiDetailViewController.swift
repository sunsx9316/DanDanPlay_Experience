//
//  BangumiDetailViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

class BangumiDetailViewController: ViewController, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {

    private let animateId: Int

    private var detail: BangumiDetail? {
        didSet {
            collectionView.reloadData()
            updateCollectionViewFrame()
        }
    }

    private enum SectionType: CaseIterable {
        case info
        case episodes
        case comments
        case relateds
        case similars
    }

    private var sections: [SectionType] = SectionType.allCases

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = NSCollectionViewFlowLayout()
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.backgroundColor]
        cv.isSelectable = true
        cv.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        cv.registerItem(class: DetailHeaderCollectionViewCell.self)
        cv.registerItem(class: DetailEpisodeRowCollectionViewCell.self)
        cv.registerItem(class: DetailCommentsRowCollectionViewCell.self)
        cv.registerItem(class: DetailRelatedCollectionViewCell.self)
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

    init(animateId: Int) {
        self.animateId = animateId
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        startRefresh()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateCollectionViewFrame()
    }

    // MARK: - Private

    private var lastCollectionViewWidth: CGFloat = 0

    private func updateCollectionViewFrame() {
        let newWidth = scrollView.contentView.bounds.width
        let contentSize = collectionView.collectionViewLayout?.collectionViewContentSize ?? .zero
        collectionView.frame = NSRect(
            x: 0,
            y: 0,
            width: newWidth,
            height: max(contentSize.height, scrollView.contentView.bounds.height)
        )
        if lastCollectionViewWidth != newWidth {
            lastCollectionViewWidth = newWidth
            collectionView.collectionViewLayout?.invalidateLayout()
        }
    }

    private func startRefresh() {
        BangumiNetworkHandle.detail(animateId: animateId) { [weak self] rsp, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.view.show(error: error)
                } else if let detail = rsp?.bangumi {
                    self.title = detail.animeTitle
                    // Recompute visible sections
                    var visible: [SectionType] = [.info, .episodes, .comments]
                    if !detail.relateds.isEmpty { visible.append(.relateds) }
                    if !detail.similars.isEmpty { visible.append(.similars) }
                    self.sections = visible
                    self.detail = detail
                }
            }
        }
    }

    private func pushDetail(animateId: Int) {
        let vc = BangumiDetailViewController(animateId: animateId)
        navigator?.pushViewController(vc)
    }

    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return detail == nil ? 0 : sections.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let type = sections[indexPath.item]
        switch type {
        case .info:
            let item = collectionView.dequeueItem(class: DetailHeaderCollectionViewCell.self, for: indexPath)
            if let detail = detail {
                item.configure(with: detail)
                item.onFavoriteToggle = { [weak self] animeId, isLike in
                    FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self?.view.show(error: error)
                            } else {
                                self?.startRefresh()
                            }
                        }
                    }
                }
                item.onTapMetadata = { [weak self] in
                    guard let self = self, let detail = self.detail else { return }
                    let vc = BangumiDetailMetadataViewController()
                    vc.configure(metaData: detail.metadata, titles: detail.titles, onlineDatabases: detail.onlineDatabases)
                    self.navigator?.pushViewController(vc)
                }
            }
            return item
        case .episodes:
            let item = collectionView.dequeueItem(class: DetailEpisodeRowCollectionViewCell.self, for: indexPath)
            item.onTap = { [weak self] in
                guard let self = self, let detail = self.detail else { return }
                let vc = BangumiDetailEpisodeViewController()
                vc.dataSource = detail.episodes
                self.navigator?.pushViewController(vc)
            }
            return item
        case .comments:
            let item = collectionView.dequeueItem(class: DetailCommentsRowCollectionViewCell.self, for: indexPath)
            item.onTap = { [weak self] in
                guard let self = self, let detail = self.detail else { return }
                let vc = BangumiCommentListViewController(bangumiId: String(detail.bangumiId))
                self.navigator?.pushViewController(vc)
            }
            return item
        case .relateds, .similars:
            let item = collectionView.dequeueItem(class: DetailRelatedCollectionViewCell.self, for: indexPath)
            if let detail = detail {
                let data = type == .relateds ? detail.relateds : detail.similars
                let title = type == .relateds ? NSLocalizedString("关联作品", comment: "") : NSLocalizedString("相似作品", comment: "")
                item.configure(title: title, items: data)
                item.onSelectAnime = { [weak self] animeId in
                    self?.pushDetail(animateId: animeId)
                }
                item.onFavoriteToggle = { [weak self] animeId, isLike in
                    FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self?.view.show(error: error)
                            } else {
                                self?.startRefresh()
                            }
                        }
                    }
                }
            }
            return item
        }
    }

    // MARK: - NSCollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        let width = collectionView.bounds.width
        let type = sections[indexPath.item]
        switch type {
        case .info:
            return NSSize(width: width, height: 170)
        case .episodes, .comments:
            return NSSize(width: width, height: 60)
        case .relateds, .similars:
            let list = type == .relateds ? (detail?.relateds ?? []) : (detail?.similars ?? [])
            guard !list.isEmpty else { return NSSize(width: width, height: 0.01) }
            let h = DetailRelatedCollectionViewCell.estimatedHeight(for: list, width: width)
            return NSSize(width: width, height: h)
        }
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}