//
//  HomePageBannerTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit
import SnapKit

extension HomePageBannerTableViewCell: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sectionCount
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return banners?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(class: HomePageBannerItemCell.self, indexPath: indexPath)
        cell.item = banners?[indexPath.item]
        return cell
    }
}

extension HomePageBannerTableViewCell: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = banners?[indexPath.item],
              let url = URL(string: item.url) else { return }
        UIApplication.shared.open(url)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let centerX = scrollView.contentOffset.x + scrollView.bounds.width / 2
        let maxDistance = scrollView.bounds.width
        for cell in collectionView.visibleCells {
            let distance = abs(cell.center.x - centerX)
            let progress = min(distance / maxDistance, 1.0)
            let scale = 1.0 - progress * 0.15
            cell.alpha = 1.0 - progress * 0.3
            cell.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        stopAutoScroll()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateCurrentPage()
        // 确保居中 cell 恢复完整状态
        resetVisibleCellsTransform()
        startAutoScroll()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateCurrentPage()
        resetVisibleCellsTransform()
    }

    private func resetVisibleCellsTransform() {
        for cell in collectionView.visibleCells {
            cell.alpha = 1.0
            cell.transform = .identity
        }
    }
}

class HomePageBannerTableViewCell: TableViewCell {

    private let sectionCount = 100
    private var currentPage = 0

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.backgroundColor = .clear
        cv.delegate = self
        cv.dataSource = self
        cv.registerClassCell(class: HomePageBannerItemCell.self)
        return cv
    }()

    private lazy var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.hidesForSinglePage = true
        pageControl.isUserInteractionEnabled = false
        return pageControl
    }()

    private var autoScrollTimer: Timer?

    var banners: [BannerPageItem]? {
        didSet {
            collectionView.reloadData()
            pageControl.numberOfPages = banners?.count ?? 0

            if let count = banners?.count, count > 0 {
                let indexPath = IndexPath(item: 0, section: sectionCount / 2)
                collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
                currentPage = 0
                pageControl.currentPage = 0
            }

            startAutoScroll()
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    deinit {
        autoScrollTimer?.invalidate()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopAutoScroll()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startAutoScroll()
        } else {
            stopAutoScroll()
        }
    }

    // MARK: Private

    private func setupUI() {
        selectionStyle = .none
        contentView.addSubview(collectionView)
        contentView.addSubview(pageControl)

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        pageControl.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
        }
    }

    private func startAutoScroll() {
        stopAutoScroll()
        guard let count = banners?.count, count > 1 else { return }
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.scrollToNextPage()
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    private func scrollToNextPage() {
        guard let count = banners?.count, count > 1 else { return }
        let pageWidth = collectionView.bounds.width
        guard pageWidth > 0 else { return }

        let nextPage = (currentPage + 1) % count
        let currentSection = Int(round(collectionView.contentOffset.x / pageWidth)) / count
        var targetSection = currentSection

        if nextPage == 0 {
            targetSection = currentSection + 1
            if targetSection >= sectionCount {
                targetSection = sectionCount / 2
            }
        }

        collectionView.scrollToItem(at: IndexPath(item: nextPage, section: targetSection), at: .centeredHorizontally, animated: true)

        currentPage = nextPage
        pageControl.currentPage = currentPage
    }

    private func updateCurrentPage() {
        let item = Int(round(collectionView.contentOffset.x / collectionView.bounds.width))
        currentPage = item % (banners?.count ?? 1)
        pageControl.currentPage = currentPage
    }
}
