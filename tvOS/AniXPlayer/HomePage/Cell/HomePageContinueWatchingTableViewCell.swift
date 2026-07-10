//
//  HomePageContinueWatchingTableViewCell.swift
//  AniXPlayer
//
//  tvOS 首页"继续播放" — TableViewCell 内嵌瀑布流 CollectionView + AnimeListCollectionViewCell
//

import UIKit
import SnapKit
import Kingfisher

extension BangumiQueueIntro: AnimeListItem {
    var rating: Double { 0 }
    var hasRating: Bool { false }
    var typeDescription: String { "" }
    var isFavorited: Bool { false }
}

class HomePageContinueWatchingTableViewCell: TableViewCell {

    var items: [BangumiQueueIntro] = [] {
        didSet {
            collectionView.reloadData()
            titleLabel.isHidden = items.isEmpty
            updateCollectionViewHeight()
        }
    }

    var onItemSelected: ((BangumiQueueIntro) -> Void)?

    private lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large(weight: .bold)
        label.textColor = .label
        label.text = NSLocalizedString("继续播放", comment: "")
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 3
        layout.sectionInset = .zero
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
        cv.registerClassCell(class: ContinueWatchingItemCell.self)
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
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(titleLabel)
        contentView.addSubview(collectionView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(60)
            make.top.equalToSuperview().offset(16)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
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

    static func estimatedHeight(for items: [BangumiQueueIntro], width: CGFloat) -> CGFloat {
        guard !items.isEmpty else { return 0 }

        let titleHeight = NSLocalizedString("继续播放", comment: "").boundingRect(
            with: CGSize(width: width - 120, height: 40),
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.ddp_large(weight: .bold)],
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

        return titleHeight + 16 + 16 + waterfallHeight + 16
    }
}

// MARK: - WaterfallLayoutDelegate

extension HomePageContinueWatchingTableViewCell: WaterfallLayoutDelegate {

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < items.count else { return itemWidth * 0.65 }
        return AnimeListCollectionViewCell.estimatedHeight(for: items[indexPath.item], width: itemWidth)
    }
}

// MARK: - ContinueWatchingItemCell

extension HomePageContinueWatchingTableViewCell {

    class ContinueWatchingItemCell: AnimeListCollectionViewCell {

        private lazy var episodeLabel: Label = {
            let label = Label()
            label.font = .ddp_small()
            label.textColor = UIColor.white.withAlphaComponent(0.75)
            label.numberOfLines = 1
            return label
        }()

        override func update(item: any AnimeListItem, ratingNumberFormatter: NumberFormatter) {
            super.update(item: item, ratingNumberFormatter: ratingNumberFormatter)

            guard let queueItem = item as? BangumiQueueIntro else { return }
            if !queueItem.episodeTitle.isEmpty {
                episodeLabel.text = queueItem.episodeTitle
                episodeLabel.isHidden = false
            } else {
                episodeLabel.isHidden = true
            }

            // 隐藏不用的 info 标签
            statusLabel.isHidden = true
            typeLabel.isHidden = true
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            // 在 infoRow 之前插入剧集标题
            overlayStackView.insertArrangedSubview(episodeLabel, at: overlayStackView.arrangedSubviews.count - 1)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension HomePageContinueWatchingTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(class: ContinueWatchingItemCell.self, indexPath: indexPath)
        cell.update(item: items[indexPath.item], ratingNumberFormatter: NumberFormatter())
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onItemSelected?(items[indexPath.item])
    }
}
