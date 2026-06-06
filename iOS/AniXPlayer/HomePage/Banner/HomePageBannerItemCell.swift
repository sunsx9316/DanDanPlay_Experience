//
//  HomePageBannerItemCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit
import SnapKit
import Kingfisher
import YYCategories

class HomePageBannerItemCell: CollectionViewCell {

    private lazy var bgImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    private lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large
        return label
    }()

    private lazy var descLabel: Label = {
        let label = Label()
        label.font = .ddp_small
        return label
    }()

    var item: BannerPageItem? {
        didSet {
            if let imageUrl = item?.imageUrl {
                bgImageView.kf.setImage(with: URL(string: imageUrl), placeholder: UIImage.placeholder)
            } else {
                bgImageView.image = nil
            }
            titleLabel.text = item?.title
            descLabel.text = item?.description
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.addSubview(bgImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descLabel)

        bgImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        descLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(10)
            make.bottom.equalToSuperview().offset(-10)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(10)
            make.bottom.equalTo(descLabel.snp.top).offset(-10)
        }

        titleLabel.setLayerShadow(.shadowColor, offset: CGSize(width: 0, height: 1), radius: 3)
        descLabel.setLayerShadow(.shadowColor, offset: CGSize(width: 0, height: 1), radius: 3)
    }
}
