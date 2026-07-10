//
//  BangumiDetailInfoTableViewCell.swift
//  AniXPlayer
//
//  tvOS 番剧详情信息 Cell — 左海报 + 右信息
//

import UIKit
import SnapKit
import Kingfisher
import YYCategories

class BangumiDetailInfoTableViewCell: TableViewCell {

    private let posterSize = CGSize(width: 360, height: 475)

    // MARK: Background

    private lazy var backgroundImageView: ImageView = {
        let iv = ImageView()
        return iv
    }()

    private lazy var blurEffectView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: blur)
        return view
    }()

    // MARK: Subviews

    private lazy var posterContainer: UIView = {
        let view = UIView()
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.2
        return view
    }()

    private lazy var posterImageView: ImageView = {
        let iv = ImageView()
        iv.layer.cornerRadius = 8
        return iv
    }()

    private lazy var favoriteImageView: ImageView = {
        let iv = ImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.shadowRadius = 3
        iv.layer.shadowOpacity = 0.5
        iv.layer.shadowOffset = .init(width: 2, height: 2)
        return iv
    }()

    private lazy var ratingBadge: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        return label
    }()

    private lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large(weight: .bold)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()

    private lazy var metaStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }()

    private lazy var ratingLabel: Label = {
        let label = Label()
        label.font = .ddp_normal(weight: .bold)
        label.textColor = .mainColor
        return label
    }()

    private lazy var onAirLabel: Label = {
        let label = Label()
        label.font = .ddp_normal()
        label.layer.cornerRadius = 5
        label.layer.masksToBounds = true
        label.layer.borderWidth = 1
        return label
    }()

    private lazy var summaryLabel: Label = {
        let label = Label()
        label.font = .ddp_normal()
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    var item: BangumiDetail?

    // MARK: Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // 背景：封面图 + dark blur
        contentView.addSubview(backgroundImageView)
        contentView.addSubview(blurEffectView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        blurEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // poster + badges
        posterContainer.addSubview(posterImageView)
        posterContainer.addSubview(ratingBadge)
        posterContainer.addSubview(favoriteImageView)
        posterImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.size.equalTo(posterSize)
        }
        ratingBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
            make.height.equalTo(38)
        }
        favoriteImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.width.height.equalTo(48)
        }

        // 标题行
        let topRow = UIStackView(arrangedSubviews: [titleLabel])
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.alignment = .center

        // 元数据行：评分 + 连载状态
        metaStack.addArrangedSubview(ratingLabel)
        metaStack.addArrangedSubview(onAirLabel)

        // 右侧信息区
        let infoStack = UIStackView(arrangedSubviews: [topRow, metaStack, summaryLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 10
        infoStack.alignment = .leading

        // root：海报 + 信息
        let rootStack = UIStackView(arrangedSubviews: [posterContainer, infoStack])
        rootStack.axis = .horizontal
        rootStack.spacing = 30
        rootStack.alignment = .top

        contentView.addSubview(rootStack)

        rootStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().offset(-60)
            make.bottom.equalToSuperview().offset(-20)
        }

    }

    // MARK: Configure

    func configure(with detail: BangumiDetail) {
        self.item = detail

        titleLabel.text = detail.animeTitle

        if let url = URL(string: detail.imageUrl) {
            posterImageView.kf.setImage(with: url, placeholder: UIImage.placeholder)
            backgroundImageView.kf.setImage(with: url, placeholder: UIImage.placeholder)
        }

        if detail.rating > 0 {
            ratingLabel.text = String(format: "⭐ %.1f", detail.rating)
            ratingLabel.isHidden = false
            ratingBadge.text = "  ⭐ " + String(format: "%.1f", detail.rating) + "  "
            ratingBadge.isHidden = false
        } else {
            ratingLabel.isHidden = true
            ratingBadge.isHidden = true
        }

        // 连载状态 pill
        if detail.isOnAir {
            onAirLabel.text = " " + NSLocalizedString("连载中", comment: "") + " "
            onAirLabel.textColor = .mainColor
            onAirLabel.backgroundColor = UIColor.mainColor.withAlphaComponent(0.12)
            onAirLabel.layer.borderColor = UIColor.mainColor.withAlphaComponent(0.25).cgColor
        } else {
            onAirLabel.text = " " + NSLocalizedString("已完结", comment: "") + " "
            onAirLabel.textColor = .secondaryLabel
            onAirLabel.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.1)
            onAirLabel.layer.borderColor = UIColor.secondaryLabel.withAlphaComponent(0.2).cgColor
        }

        summaryLabel.text = detail.summary
        summaryLabel.isHidden = detail.summary.isEmpty

        changeFavoritedStatus(isFavorited: detail.isFavorited)
    }

    private func changeFavoritedStatus(isFavorited: Bool) {
        let imageName = isFavorited ? "Like" : "Unlike"
        favoriteImageView.image = UIImage(named: imageName)?.byResize(to: CGSize(width: 48, height: 48))?.byTintColor(.mainColor)
    }
}
