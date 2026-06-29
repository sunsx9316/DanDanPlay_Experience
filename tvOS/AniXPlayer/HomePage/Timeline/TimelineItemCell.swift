//
//  TimelineItemCell.swift
//  AniXPlayer
//
//  tvOS 新番时间表 Cell — 网格海报卡片风格
//

import UIKit
import SnapKit
import Kingfisher

class TimelineItemCell: CollectionViewCell {

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
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private lazy var statusLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        label.textAlignment = .center
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
        contentView.addSubview(statusLabel)

        posterImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(posterImageView.snp.width).multipliedBy(9.0 / 16.0)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(posterImageView.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(4)
        }

        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
        }
    }

    func configure(with item: BangumiIntro) {
        titleLabel.text = item.animeTitle
        statusLabel.text = item.isOnAir ? NSLocalizedString("连载中", comment: "") : NSLocalizedString("已完结", comment: "")
        if let url = URL(string: item.imageUrl) {
            posterImageView.kf.setImage(with: url, placeholder: UIImage.placeholder)
        }
    }
}
