//
//  TimelineItemCell.swift
//  AniXPlayer
//
//  tvOS 新番时间表 Cell
//

import UIKit
import SnapKit
import Kingfisher

class TimelineItemCell: CollectionViewCell {

    static let reuseIdentifier = "TimelineItemCell"

    private let posterImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return iv
    }()

    private let titleLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .lightGray
        return label
    }()

    private let statusLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .lightGray
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
        contentView.addSubview(statusLabel)

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

        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
        }
    }

    func configure(with item: BangumiIntro) {
        titleLabel.text = item.animeTitle
        statusLabel.text = item.isOnAir ? NSLocalizedString("连载中", comment: "") : NSLocalizedString("已完结", comment: "")
        if let url = URL(string: item.imageUrl) {
            posterImageView.kf.setImage(with: url)
        }
    }
}
