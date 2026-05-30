//
//  BangumiDetailInfoViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import Kingfisher
import YYCategories

class BangumiDetailInfoViewCell: TableViewCell {

    private let arrowImageSize = CGSize(width: 16, height: 16)

    lazy var imgView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    lazy var titleLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
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

    lazy var tagsLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()

    lazy var arrowButton: Button = {
        let btn = Button()
        btn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        btn.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return btn
    }()

    var didTouchLikeButton: ((BangumiDetailInfoViewCell, Bool) -> Void)?

    var touchArrowButton: (() -> Void)?

    func update(item: BangumiDetail?, ratingNumberFormatter: NumberFormatter) {
        self.item = item

        if let url = self.item?.imageUrl {
            self.imgView.kf.setImage(with: URL(string: url))
        } else {
            self.imgView.image = nil
        }

        self.titleLabel.text = self.item?.animeTitle
        self.ratingLabel.text = ratingNumberFormatter.string(from: NSNumber(value: self.item?.rating ?? 0))
        self.isOnAirLabel.text = self.item?.isOnAir == true ? NSLocalizedString("连载中", comment: "") : "已完结"

        if let tags = item?.tags {
            let sortTags = tags.sorted { tag1, tag2 in
                return tag1.count > tag2.count
            }

            self.tagsLabel.text = sortTags.reduce("") { partialResult, tag in
                if partialResult.isEmpty {
                    return tag.name
                }
                return partialResult + ", " + tag.name
            }
        } else {
            self.tagsLabel.text = nil
        }

        changeFavoritedStatus(isFavorited: self.item?.isFavorited == true)
    }

    var item: BangumiDetail?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(imgView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(ratingLabel)
        contentView.addSubview(favoritedButton)
        contentView.addSubview(isOnAirLabel)
        contentView.addSubview(tagsLabel)
        contentView.addSubview(arrowButton)

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
        }

        isOnAirLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.equalTo(titleLabel)
        }

        tagsLabel.snp.makeConstraints { make in
            make.top.equalTo(isOnAirLabel.snp.bottom).offset(10)
            make.leading.equalTo(isOnAirLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-10)
        }

        arrowButton.snp.makeConstraints { make in
            make.centerY.equalTo(imgView)
            make.trailing.equalToSuperview().offset(-10)
            make.leading.greaterThanOrEqualTo(tagsLabel.snp.trailing).offset(5)
            make.leading.greaterThanOrEqualTo(favoritedButton.snp.trailing).offset(5)
            make.width.height.equalTo(arrowImageSize)
        }

        favoritedButton.addTarget(self, action: #selector(onTouchLikeButton(_:)), for: .touchUpInside)
        arrowButton.addTarget(self, action: #selector(onTouchArrowButton(_:)), for: .touchUpInside)

        self.titleLabel.font = .ddp_large
        self.isOnAirLabel.font = .ddp_normal
        self.isOnAirLabel.textColor = .subtitleTextColor
        self.ratingLabel.font = UIFont.boldSystemFont(ofSize: 18)
        self.ratingLabel.textColor = .mainColor
        self.tagsLabel.font = .ddp_small
        self.tagsLabel.textColor = .subtitleTextColor
        self.favoritedButton.setTitle(nil, for: .normal)
        self.arrowButton.setTitle(nil, for: .normal)
        self.arrowButton.setImage(UIImage(named: "Public/right_arrow")?.byTintColor(.navItemColor), for: .normal)
        self.arrowButton.touchAreaEdgeInsets = .init(top: -30, left: -10, bottom: -30, right: -10)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onTouchLikeButton(_ sender: Button) {
        let isFavorited = self.item?.isFavorited == true
        changeFavoritedStatus(isFavorited: !isFavorited)
        self.didTouchLikeButton?(self, !isFavorited)
    }

    @objc private func onTouchArrowButton(_ sender: UIButton) {
        self.touchArrowButton?()
    }

    private func changeFavoritedStatus(isFavorited: Bool) {
        let imageName = isFavorited ? "Like" : "Unlike"
        self.favoritedButton.setImage(UIImage(named: imageName)?.byResize(to: CGSize(width: 20, height: 20))?.byTintColor(.mainColor), for: .normal)
    }

}
