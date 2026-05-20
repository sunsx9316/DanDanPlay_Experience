//
//  HomePageViewController.swift
//  AniXPlayer
//
//  tvOS 首页 — CollectionView 网格布局 + 焦点驱动
//

import UIKit
import SnapKit

class HomePageViewController: ViewController {

    private enum Section: Int, CaseIterable {
        case continueWatching
        case functions
    }

    private enum FunctionItem: Int, CaseIterable {
        case bangumi
        case fileBrowser
        case search

        var title: String {
            switch self {
            case .bangumi: return NSLocalizedString("番剧", comment: "")
            case .fileBrowser: return NSLocalizedString("文件浏览", comment: "")
            case .search: return NSLocalizedString("搜索", comment: "")
            }
        }

        var iconName: String {
            switch self {
            case .bangumi: return "tv"
            case .fileBrowser: return "folder"
            case .search: return "magnifyingglass"
            }
        }
    }

    private lazy var collectionView: CollectionView = {
        let layout = Self.createLayout()
        let cv = CollectionView(frame: .zero, collectionViewLayout: layout)
        cv.delegate = self
        cv.dataSource = self
        cv.register(HomePageContinueWatchingCell.self, forCellWithReuseIdentifier: HomePageContinueWatchingCell.reuseIdentifier)
        cv.register(HomePageFunctionCell.self, forCellWithReuseIdentifier: HomePageFunctionCell.reuseIdentifier)
        cv.register(HomePageSectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: HomePageSectionHeaderView.reuseIdentifier)
        return cv
    }()

    private var continueWatchingItems: [BangumiQueueIntro] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("主页", comment: "")

        self.view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = collectionView
    }

    // MARK: - Data

    private func loadData() {
        HomePageNetworkHandle.homePage() { [weak self] homepage, error in
            guard let self = self else { return }
            if let homepage = homepage {
                self.continueWatchingItems = homepage.bangumiQueueIntroList
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            }
        }
    }

    // MARK: - Layout

    private static func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { sectionIndex, _ in
            guard let section = Section(rawValue: sectionIndex) else { return nil }

            switch section {
            case .continueWatching:
                let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(300), heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(300), heightDimension: .absolute(200))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                let sectionLayout = NSCollectionLayoutSection(group: group)
                sectionLayout.orthogonalScrollingBehavior = .continuous
                sectionLayout.interGroupSpacing = 20
                sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 60, bottom: 0, trailing: 60)

                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
                sectionLayout.boundarySupplementaryItems = [header]

                return sectionLayout

            case .functions:
                let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(200), heightDimension: .absolute(140))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(140))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                group.interItemSpacing = .fixed(20)

                let sectionLayout = NSCollectionLayoutSection(group: group)
                sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 60, bottom: 40, trailing: 60)
                sectionLayout.interGroupSpacing = 20

                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
                sectionLayout.boundarySupplementaryItems = [header]

                return sectionLayout
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension HomePageViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Section.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .continueWatching:
            return continueWatchingItems.count
        case .functions:
            return FunctionItem.allCases.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UICollectionViewCell()
        }

        switch sectionType {
        case .continueWatching:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HomePageContinueWatchingCell.reuseIdentifier, for: indexPath) as! HomePageContinueWatchingCell
            let item = continueWatchingItems[indexPath.item]
            cell.configure(with: item)
            return cell

        case .functions:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HomePageFunctionCell.reuseIdentifier, for: indexPath) as! HomePageFunctionCell
            if let item = FunctionItem(rawValue: indexPath.item) {
                cell.configure(title: item.title, iconName: item.iconName)
            }
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: HomePageSectionHeaderView.reuseIdentifier, for: indexPath) as! HomePageSectionHeaderView

        guard let sectionType = Section(rawValue: indexPath.section) else { return header }

        switch sectionType {
        case .continueWatching:
            header.title = continueWatchingItems.isEmpty ? "" : NSLocalizedString("继续播放", comment: "")
        case .functions:
            header.title = NSLocalizedString("功能入口", comment: "")
        }

        return header
    }
}

// MARK: - UICollectionViewDelegate

extension HomePageViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let sectionType = Section(rawValue: indexPath.section) else { return }

        switch sectionType {
        case .continueWatching:
            let item = continueWatchingItems[indexPath.item]
            let detailVC = BangumiDetailViewController(animateId: item.animeId)
            self.navigationController?.pushViewController(detailVC, animated: true)

        case .functions:
            guard let item = FunctionItem(rawValue: indexPath.item) else { return }
            switch item {
            case .bangumi:
                let timelineVC = TimelineViewController()
                self.navigationController?.pushViewController(timelineVC, animated: true)
            case .fileBrowser:
                let fileBrowserVC = FileBrowserViewController()
                self.navigationController?.pushViewController(fileBrowserVC, animated: true)
            case .search:
                let searchVC = SearchViewController()
                self.navigationController?.pushViewController(searchVC, animated: true)
            }
        }
    }
}
