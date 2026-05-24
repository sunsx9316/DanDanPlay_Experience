//
//  TimelineViewController.swift
//  AniXPlayer
//
//  tvOS 新番时间表 — 按星期分组，网格排版
//

import UIKit
import SnapKit

class TimelineViewController: ViewController {

    private var dataSource: [BangumiIntro] = []

    private lazy var collectionView: CollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 24
        layout.minimumInteritemSpacing = 24
        layout.sectionInset = UIEdgeInsets(top: 0, left: 60, bottom: 32, right: 60)
        layout.headerReferenceSize = CGSize(width: 0, height: 80)

        let cv = CollectionView(frame: .zero, collectionViewLayout: layout)
        cv.delegate = self
        cv.dataSource = self
        cv.register(TimelineItemCell.self, forCellWithReuseIdentifier: TimelineItemCell.reuseIdentifier)
        cv.register(HomePageSectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: HomePageSectionHeaderView.reuseIdentifier)
        return cv
    }()

    private var weekdayKeys: [Int] = []
    private var groupedData: [Int: [BangumiIntro]] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("新番时间表", comment: "")

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

    private func loadData() {
        HomePageNetworkHandle.homePage() { [weak self] homepage, error in
            guard let self = self else { return }
            if let list = homepage?.shinBangumiList {
                self.dataSource = list
                self.groupData(list)
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            }
        }
    }

    private func groupData(_ list: [BangumiIntro]) {
        groupedData.removeAll()
        for item in list {
            groupedData[item.airDay, default: []].append(item)
        }
        weekdayKeys = groupedData.keys.sorted()
    }

    private func weekdayName(for day: Int) -> String {
        let names = [
            NSLocalizedString("周日", comment: ""),
            NSLocalizedString("周一", comment: ""),
            NSLocalizedString("周二", comment: ""),
            NSLocalizedString("周三", comment: ""),
            NSLocalizedString("周四", comment: ""),
            NSLocalizedString("周五", comment: ""),
            NSLocalizedString("周六", comment: ""),
        ]
        guard day >= 0, day < names.count else { return "" }
        return names[day]
    }
}

extension TimelineViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return weekdayKeys.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let key = weekdayKeys[section]
        return groupedData[key]?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TimelineItemCell.reuseIdentifier, for: indexPath) as! TimelineItemCell
        let key = weekdayKeys[indexPath.section]
        if let item = groupedData[key]?[indexPath.item] {
            cell.configure(with: item)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: HomePageSectionHeaderView.reuseIdentifier, for: indexPath) as! HomePageSectionHeaderView
        let key = weekdayKeys[indexPath.section]
        header.title = weekdayName(for: key)
        return header
    }
}

extension TimelineViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let insets: CGFloat = 120 // 60 + 60
        let spacing: CGFloat = 24 * 3 // 3 gaps between 4 columns
        let availableWidth = collectionView.bounds.width - insets - spacing
        let itemWidth = floor(availableWidth / 4)
        let itemHeight = itemWidth * 9.0 / 16.0 + 56 // poster + title + status
        return CGSize(width: itemWidth, height: itemHeight)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let key = weekdayKeys[indexPath.section]
        if let item = groupedData[key]?[indexPath.item] {
            let detailVC = BangumiDetailViewController(animateId: item.animeId)
            self.navigationController?.pushViewController(detailVC, animated: true)
        }
    }
}
