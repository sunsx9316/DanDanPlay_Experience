//
//  BangumiDetailInfoTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import Kingfisher
import YYCategories

class BangumiDetailInfoTableViewCell: TableViewCell {

    private let posterSize = CGSize(width: 110, height: 145)
    private let arrowImageSize = CGSize(width: 16, height: 16)

    private lazy var posterContainer: UIView = {
        let view = UIView()
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.15
        return view
    }()

    lazy var imgView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = .placeholderColor
        return iv
    }()

    private lazy var ratingBadge: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 11)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        return label
    }()

    lazy var titleLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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

    lazy var arrowButton: Button = {
        let btn = Button()
        btn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        btn.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return btn
    }()

    var didTouchLikeButton: ((BangumiDetailInfoTableViewCell, Bool) -> Void)?

    var touchArrowButton: (() -> Void)?

    func update(item: BangumiDetail?, ratingNumberFormatter: NumberFormatter) {
        self.item = item

        if let url = self.item?.imageUrl {
            self.imgView.kf.setImage(with: URL(string: url), placeholder: UIImage.placeholder)
        } else {
            self.imgView.image = UIImage.placeholder
        }

        self.titleLabel.text = self.item?.animeTitle

        if let ratingText = ratingNumberFormatter.string(from: NSNumber(value: self.item?.rating ?? 0)) {
            ratingBadge.text = "  ⭐ " + ratingText + "  "
            ratingBadge.isHidden = false
        } else {
            ratingBadge.isHidden = true
        }

        if self.item?.isOnAir == true {
            self.isOnAirLabel.text = NSLocalizedString("连载中", comment: "")
            self.isOnAirLabel.textColor = .mainColor
        } else {
            self.isOnAirLabel.text = NSLocalizedString("已完结", comment: "")
            self.isOnAirLabel.textColor = .subtitleTextColor
        }

        changeFavoritedStatus(isFavorited: self.item?.isFavorited == true)
    }

    var item: BangumiDetail?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // poster
        posterContainer.addSubview(imgView)
        posterContainer.addSubview(ratingBadge)
        imgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.size.equalTo(posterSize)
        }
        ratingBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
            make.height.equalTo(20)
        }

        // info stack
        let topRow = UIStackView(arrangedSubviews: [titleLabel, favoritedButton])
        topRow.axis = .horizontal
        topRow.spacing = 10
        topRow.alignment = .center

        let infoStack = UIStackView(arrangedSubviews: [topRow, isOnAirLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 6
        infoStack.alignment = .leading

        // root
        let rootStack = UIStackView(arrangedSubviews: [posterContainer, infoStack])
        rootStack.axis = .horizontal
        rootStack.spacing = 12
        rootStack.alignment = .top

        contentView.addSubview(rootStack)
        contentView.addSubview(arrowButton)

        rootStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(15)
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }

        arrowButton.snp.makeConstraints { make in
            make.centerY.equalTo(posterContainer)
            make.trailing.equalToSuperview().offset(-10)
            make.leading.greaterThanOrEqualTo(rootStack.snp.trailing).offset(10)
            make.width.height.equalTo(arrowImageSize)
        }

        favoritedButton.addTarget(self, action: #selector(onTouchLikeButton(_:)), for: .touchUpInside)
        arrowButton.addTarget(self, action: #selector(onTouchArrowButton(_:)), for: .touchUpInside)

        self.titleLabel.font = .ddp_large
        self.isOnAirLabel.font = .ddp_normal
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
