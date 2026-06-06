//
//  BangumiDetailInfoCell.swift
//  AniXPlayer
//
//  tvOS 番剧详情信息 Cell — 海报在左，文字信息在右，横向布局
//

import UIKit
import SnapKit
import Kingfisher

class BangumiDetailInfoCell: TableViewCell {

    static let reuseIdentifier = "BangumiDetailInfoCell"

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
        label.font = .ddp_normal(weight: .bold)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()

    private lazy var ratingLabel: Label = {
        let label = Label()
        label.font = .ddp_small(weight: .bold)
        label.textColor = .systemOrange
        return label
    }()

    private lazy var onAirLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var tagsLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()

    private lazy var summaryLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.addSubview(posterImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(ratingLabel)
        contentView.addSubview(onAirLabel)
        contentView.addSubview(tagsLabel)
        contentView.addSubview(summaryLabel)

        posterImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(60)
            make.top.equalToSuperview().offset(20)
            make.width.equalTo(200)
            make.height.equalTo(112)
            make.bottom.lessThanOrEqualToSuperview().offset(-20)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(posterImageView.snp.trailing).offset(24)
            make.trailing.equalToSuperview().offset(-60)
            make.top.equalTo(posterImageView)
        }

        ratingLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }

        onAirLabel.snp.makeConstraints { make in
            make.leading.equalTo(ratingLabel.snp.trailing).offset(12)
            make.centerY.equalTo(ratingLabel)
        }

        tagsLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(ratingLabel.snp.bottom).offset(6)
        }

        summaryLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(tagsLabel.snp.bottom).offset(8)
            make.bottom.equalToSuperview().offset(-20)
        }
    }

    func configure(with detail: BangumiDetail) {
        titleLabel.text = detail.animeTitle

        if detail.rating > 0 {
            ratingLabel.text = String(format: "★ %.1f", detail.rating)
            ratingLabel.isHidden = false
        } else {
            ratingLabel.isHidden = true
        }

        onAirLabel.text = detail.isOnAir ? NSLocalizedString("连载中", comment: "") : NSLocalizedString("已完结", comment: "")

        if !detail.tags.isEmpty {
            let sortedTags = detail.tags.sorted { $0.count > $1.count }
            tagsLabel.text = sortedTags.prefix(8).map { $0.name }.joined(separator: " · ")
            tagsLabel.isHidden = false
        } else {
            tagsLabel.isHidden = true
        }

        summaryLabel.text = detail.summary
        summaryLabel.isHidden = detail.summary.isEmpty

        if let url = URL(string: detail.imageUrl) {
            posterImageView.kf.setImage(with: url, placeholder: UIImage.placeholder)
        }
    }
}
