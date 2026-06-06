//
//  TimelineItemCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import Kingfisher
import YYCategories

class TimelineItemCollectionViewCell: CollectionViewCell {

    lazy var imgView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    lazy var titleLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    lazy var ratingLabel: Label = {
        let label = Label()
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()

    lazy var favoritedButton: Button = {
        let btn = Button()
        btn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        btn.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return btn
    }()

    lazy var isOnAirLabel: Label = {
        let label = Label()
        return label
    }()

    var didTouchLikeButton: ((TimelineItemCollectionViewCell, Bool) -> Void)?

    func update(item: BangumiIntro?, ratingNumberFormatter: NumberFormatter) {
        self.item = item

        if let url = self.item?.imageUrl {
            self.imgView.kf.setImage(with: URL(string: url), placeholder: UIImage.placeholder)
        } else {
            self.imgView.image = nil
        }

        self.titleLabel.text = self.item?.animeTitle
        self.ratingLabel.text = ratingNumberFormatter.string(from: NSNumber(value: self.item?.rating ?? 0))
        self.isOnAirLabel.text = self.item?.isOnAir == true ? NSLocalizedString("连载中", comment: "") : "已完结"
        changeFavoritedStatus(isFavorited: self.item?.isFavorited == true)
    }

    var item: BangumiIntro?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(imgView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(ratingLabel)
        contentView.addSubview(favoritedButton)
        contentView.addSubview(isOnAirLabel)

        imgView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(10)
            make.width.equalTo(100)
            make.height.equalTo(120)
            make.bottom.lessThanOrEqualToSuperview().offset(-10)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(imgView.snp.trailing).offset(10)
            make.top.equalTo(imgView).offset(5)
        }

        ratingLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(10)
            make.top.equalTo(titleLabel)
        }

        favoritedButton.snp.makeConstraints { make in
            make.leading.equalTo(ratingLabel.snp.trailing).offset(10)
            make.centerY.equalTo(ratingLabel)
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
        }

        isOnAirLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.equalTo(titleLabel)
        }

        favoritedButton.addTarget(self, action: #selector(onTouchLikeButton(_:)), for: .touchUpInside)

        self.titleLabel.font = .ddp_large
        self.isOnAirLabel.font = .ddp_normal
        self.isOnAirLabel.textColor = .subtitleTextColor
        self.ratingLabel.font = UIFont.boldSystemFont(ofSize: 18)
        self.ratingLabel.textColor = .mainColor
        self.favoritedButton.setTitle(nil, for: .normal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onTouchLikeButton(_ sender: Button) {
        let isFavorited = self.item?.isFavorited == true
        self.didTouchLikeButton?(self, !isFavorited)
        changeFavoritedStatus(isFavorited: !isFavorited)
    }

    private func changeFavoritedStatus(isFavorited: Bool) {
        let imageName = isFavorited ? "Like" : "Unlike"
        self.favoritedButton.setImage(UIImage(named: imageName)?.byResize(to: CGSize(width: 20, height: 20))?.byTintColor(.mainColor), for: .normal)
    }

}
