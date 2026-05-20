//
//  HomePageContinueWatchingCell.swift
//  AniXPlayer
//
//  tvOS 首页"继续播放"Cell
//

import UIKit
import SnapKit
import Kingfisher

class HomePageContinueWatchingCell: CollectionViewCell {

    static let reuseIdentifier = "HomePageContinueWatchingCell"

    private let posterImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return iv
    }()

    private let titleLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .lightGray
        label.textAlignment = .center
        label.numberOfLines = 2
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

        posterImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.equalTo(240)
            make.height.equalTo(135)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(posterImageView.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(8)
        }
    }

    func configure(with item: BangumiQueueIntro) {
        titleLabel.text = item.animeTitle
        if let url = URL(string: item.imageUrl) {
            posterImageView.kf.setImage(with: url)
        }
    }
}
