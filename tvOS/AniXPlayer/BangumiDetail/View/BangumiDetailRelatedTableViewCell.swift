//
//  BangumiDetailRelatedTableViewCell.swift
//  AniXPlayer
//
//  tvOS 番剧详情关联/相似作品 — TableViewCell 内嵌瀑布流 CollectionView + AnimeListCollectionViewCell
//

import UIKit
import SnapKit

class BangumiDetailRelatedTableViewCell: TableViewCell {

    var items: [BangumiIntro] = [] {
        didSet {
            collectionView.reloadData()
            updateCollectionViewHeight()
        }
    }

    var onItemSelected: ((Int) -> Void)?

    let titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large()
        label.textColor = .label
        return label
    }()

    private lazy var ratingNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.roundingMode = .halfEven
        return formatter
    }()

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 3
        layout.itemPadding = 40
        layout.delegate = self
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: waterfallLayout)
        cv.backgroundColor = .clear
        cv.isScrollEnabled = false
        cv.delegate = self
        cv.dataSource = self
        cv.registerClassCell(class: AnimeListCollectionViewCell.self)
        return cv
    }()

    private var collectionViewHeightConstraint: Constraint?

    override var canBecomeFocused: Bool { return false }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return items.isEmpty ? [] : [collectionView]
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none

        contentView.addSubview(titleLabel)
        contentView.addSubview(collectionView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(60)
            make.top.equalToSuperview().offset(16)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().offset(-60)
            make.bottom.equalToSuperview().offset(-16).priority(999)
            collectionViewHeightConstraint = make.height.equalTo(1).constraint
        }
    }

    private func updateCollectionViewHeight() {
        collectionView.layoutIfNeeded()
        let contentSize = waterfallLayout.collectionViewContentSize
        collectionViewHeightConstraint?.update(offset: contentSize.height)
    }

    static func estimatedHeight(for items: [BangumiIntro], width: CGFloat) -> CGFloat {
        guard !items.isEmpty else { return 0 }

        let titleHeight = NSLocalizedString("关联作品", comment: "").boundingRect(
            with: CGSize(width: width - 120, height: 60),
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.ddp_large()],
            context: nil
        ).height.rounded(.up)

        let layout = WaterfallLayout()
        layout.columnCount = 3
        layout.itemPadding = 40
        layout.sectionInset = .zero
        let availableWidth = width - 120
        let itemWidth = (availableWidth - layout.itemPadding * CGFloat(layout.columnCount - 1)) / CGFloat(layout.columnCount)

        var columnHeights = Array(repeating: CGFloat(0), count: layout.columnCount)
        for item in items {
            let column = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let height = AnimeListCollectionViewCell.estimatedHeight(for: item, width: itemWidth)
            columnHeights[column] = columnHeights[column] + height + layout.itemPadding
        }
        let waterfallHeight = (columnHeights.max() ?? 0)

        return titleHeight + 16 + 12 + waterfallHeight + 16
    }
}

// MARK: - WaterfallLayoutDelegate

extension BangumiDetailRelatedTableViewCell: WaterfallLayoutDelegate {

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < items.count else { return itemWidth * 0.65 }
        return AnimeListCollectionViewCell.estimatedHeight(for: items[indexPath.item], width: itemWidth)
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension BangumiDetailRelatedTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(class: AnimeListCollectionViewCell.self, indexPath: indexPath)
        cell.update(item: items[indexPath.item], ratingNumberFormatter: ratingNumberFormatter)
        // 关联/相似作品不需要状态和类型标签
        cell.statusLabel.isHidden = true
        cell.typeLabel.isHidden = true
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onItemSelected?(items[indexPath.item].animeId)
    }
}
