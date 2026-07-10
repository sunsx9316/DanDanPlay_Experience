//
//  FavoriteItemCollectionViewCell.swift
//  AniXPlayer
//
//  tvOS 收藏 Cell — 继承 AnimeListCollectionViewCell，追加观看进度
//

import UIKit

extension UserFavoriteItem: AnimeListItem {
    var hasRating: Bool { true }
    var typeDescription: String { type.displayName }
    var isFavorited: Bool { favoriteStatus == .favorited }
}

class FavoriteItemCollectionViewCell: AnimeListCollectionViewCell {

    private lazy var progressLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        return label
    }()

    override func update(item: any AnimeListItem, ratingNumberFormatter: NumberFormatter) {
        super.update(item: item, ratingNumberFormatter: ratingNumberFormatter)

        guard let favItem = item as? UserFavoriteItem else { return }
        progressLabel.text = String(format: NSLocalizedString("进度: %d/%d 集", comment: ""), favItem.episodeWatched, favItem.episodeTotal)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        // 在 infoRow 之前插入进度标签
        overlayStackView.insertArrangedSubview(progressLabel, at: overlayStackView.arrangedSubviews.count - 1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
