//
//  FavoriteItemCell.swift
//  AniXPlayer
//
//  tvOS 收藏 Cell
//

import UIKit
import SnapKit
import Kingfisher

class FavoriteItemCell: CollectionViewCell {

    private lazy var posterImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return iv
    }()

    private lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_small(weight: .medium)
        label.textColor = .label
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
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        contentView.layer.cornerRadius = 8

        contentView.addSubview(posterImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(progressLabel)

        posterImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.equalTo(100)
            make.height.equalTo(56)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(posterImageView.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalTo(posterImageView).offset(4)
        }

        progressLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
        }
    }

    func configure(with item: UserFavoriteItem) {
        titleLabel.text = item.animeTitle
        progressLabel.text = "\(NSLocalizedString("已看", comment: "")) \(item.episodeWatched)/\(item.episodeTotal)"
        if let url = URL(string: item.imageUrl) {
            posterImageView.kf.setImage(with: url, placeholder: UIImage.placeholder)
        }
    }
}
