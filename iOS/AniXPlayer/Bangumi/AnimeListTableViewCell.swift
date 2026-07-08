//
//  AnimeListTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/8.
//

import UIKit
import Kingfisher
import SnapKit
import YYCategories

// MARK: - Protocol

protocol AnimeListItem {
    var animeId: Int { get }
    var animeTitle: String { get }
    var imageUrl: String { get }
    var rating: Double { get }
    var typeDescription: String { get }
    var isOnAir: Bool { get }
    var isFavorited: Bool { get }
}

// MARK: - AnimeListTableViewCell

class AnimeListTableViewCell: TableViewCell {

    private let posterSize = CGSize(width: 110, height: 145)

    // MARK: Subviews

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

    lazy var typeLabel: Label = {
        let label = Label()
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.layer.borderWidth = 0.5
        return label
    }()

    /// 子类可向此 StackView 插入额外视图
    lazy var infoStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        return stack
    }()

    private lazy var topRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        return stack
    }()

    var didTouchLikeButton: ((AnimeListTableViewCell, Bool) -> Void)?

    // MARK: Update

    func update(item: AnimeListItem, ratingNumberFormatter: NumberFormatter) {
        self.item = item

        if !item.imageUrl.isEmpty {
            self.imgView.kf.setImage(with: URL(string: item.imageUrl), placeholder: UIImage.placeholder)
        } else {
            self.imgView.image = UIImage.placeholder
        }

        self.titleLabel.text = item.animeTitle

        if let ratingText = ratingNumberFormatter.string(from: NSNumber(value: item.rating)) {
            ratingBadge.text = "  ⭐ " + ratingText + "  "
            ratingBadge.isHidden = false
        } else {
            ratingBadge.isHidden = true
        }

        if item.isOnAir {
            self.isOnAirLabel.text = NSLocalizedString("连载中", comment: "")
            self.isOnAirLabel.textColor = .mainColor
        } else {
            self.isOnAirLabel.text = NSLocalizedString("已完结", comment: "")
            self.isOnAirLabel.textColor = .subtitleTextColor
        }

        if !item.typeDescription.isEmpty {
            self.typeLabel.text = " " + item.typeDescription + " "
            self.typeLabel.textColor = .mainColor
            self.typeLabel.backgroundColor = UIColor.mainColor.withAlphaComponent(0.12)
            self.typeLabel.layer.borderColor = UIColor.mainColor.withAlphaComponent(0.25).cgColor
            self.typeLabel.isHidden = false
        } else {
            self.typeLabel.isHidden = true
        }

        changeFavoritedStatus(isFavorited: item.isFavorited)
    }

    var item: AnimeListItem?

    // MARK: Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // poster container
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

        // top row
        topRowStack.addArrangedSubview(titleLabel)
        topRowStack.addArrangedSubview(favoritedButton)

        // info stack
        infoStackView.addArrangedSubview(topRowStack)
        infoStackView.addArrangedSubview(isOnAirLabel)
        infoStackView.addArrangedSubview(typeLabel)

        // root stack
        let rootStack = UIStackView(arrangedSubviews: [posterContainer, infoStackView])
        rootStack.axis = .horizontal
        rootStack.spacing = 12
        rootStack.alignment = .top

        contentView.addSubview(rootStack)

        rootStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-15)
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }

        favoritedButton.addTarget(self, action: #selector(onTouchLikeButton(_:)), for: .touchUpInside)

        self.titleLabel.font = .ddp_large
        self.isOnAirLabel.font = .ddp_normal
        self.typeLabel.font = .ddp_small
        self.favoritedButton.setTitle(nil, for: .normal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Actions

    @objc private func onTouchLikeButton(_ sender: Button) {
        let isFavorited = self.item?.isFavorited == true
        self.didTouchLikeButton?(self, !isFavorited)
        changeFavoritedStatus(isFavorited: !isFavorited)
    }

    func changeFavoritedStatus(isFavorited: Bool) {
        let imageName = isFavorited ? "Like" : "Unlike"
        self.favoritedButton.setImage(UIImage(named: imageName)?.byResize(to: CGSize(width: 20, height: 20))?.byTintColor(.mainColor), for: .normal)
    }
}
