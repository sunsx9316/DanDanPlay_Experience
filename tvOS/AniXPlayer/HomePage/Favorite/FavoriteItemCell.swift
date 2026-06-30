//
//  FavoriteItemCell.swift
//  AniXPlayer
//
//  tvOS 收藏 Cell — 瀑布流卡片
//

import UIKit
import SnapKit
import Kingfisher

class FavoriteItemCell: CollectionViewCell {

    private lazy var posterImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        iv.adjustsImageWhenAncestorFocused = true
        return iv
    }()

    private lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_small(weight: .medium)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()

    private lazy var progressLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.addSubview(posterImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(progressLabel)

        posterImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(posterImageView.snp.width).multipliedBy(9.0 / 16.0)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(posterImageView.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().offset(-4)
        }

        progressLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.bottom.lessThanOrEqualToSuperview().offset(-8)
        }
    }

    func configure(with item: UserFavoriteItem) {
        titleLabel.text = item.animeTitle
        progressLabel.text = String(format: NSLocalizedString("已看 %d/%d", comment: ""), item.episodeWatched, item.episodeTotal)
        if let url = URL(string: item.imageUrl) {
            posterImageView.kf.setImage(with: url, placeholder: UIImage.placeholder)
        }
    }

    static func estimatedHeight(for item: UserFavoriteItem, width: CGFloat) -> CGFloat {
        let imageHeight = width * 9.0 / 16.0
        let titleHeight = item.animeTitle.boundingRect(
            with: CGSize(width: width - 8, height: 44),
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.ddp_small(weight: .medium)],
            context: nil
        ).height.rounded(.up)
        let progressHeight = String(format: NSLocalizedString("已看 %d/%d", comment: ""), item.episodeWatched, item.episodeTotal).boundingRect(
            with: CGSize(width: width - 8, height: 30),
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.ddp_small()],
            context: nil
        ).height.rounded(.up)
        return imageHeight + 8 + titleHeight + 4 + progressHeight + 8
    }
}
