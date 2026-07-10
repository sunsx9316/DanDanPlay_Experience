//
//  AnimeListCollectionViewCell.swift
//  AniXPlayer
//
//  tvOS 番剧列表瀑布流 Cell — 海报铺满 + 底部半透明遮罩 + StackView 文字区
//

import UIKit
import Kingfisher
import SnapKit

// MARK: - Protocol

protocol AnimeListItem {
    var animeId: Int { get }
    var animeTitle: String { get }
    var imageUrl: String { get }
    var rating: Double { get }
    var hasRating: Bool { get }
    var typeDescription: String { get }
    var isOnAir: Bool { get }
    var isFavorited: Bool { get }
}

// MARK: - AnimeListCollectionViewCell

class AnimeListCollectionViewCell: CollectionViewCell {

    // MARK: Subviews

    private lazy var posterImageView: ImageView = {
        let iv = ImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        iv.adjustsImageWhenAncestorFocused = true
        return iv
    }()

    /// 底部半透明遮罩
    private lazy var textOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        view.layer.cornerRadius = 12
        view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        view.clipsToBounds = true
        return view
    }()

    /// 子类可向此 StackView 插入额外视图（在 infoRow 之前/之后均可）
    lazy var overlayStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        return stack
    }()

    private lazy var ratingBadge: UILabel = {
        let label = Label()
        label.font = UIFont.boldSystemFont(ofSize: 22)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.mainColor.withAlphaComponent(0.85)
        label.layer.cornerRadius = 5
        label.layer.masksToBounds = true
        return label
    }()

    lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large()
        label.textColor = .white
        label.numberOfLines = 3
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 3
        label.layer.shadowOpacity = 0.5
        return label
    }()

    lazy var infoRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    lazy var statusLabel: Label = {
        let label = Label()
        label.font = .ddp_normal()
        return label
    }()

    lazy var typeLabel: Label = {
        let label = Label()
        label.font = .ddp_normal()
        return label
    }()

    // MARK: Update

    func update(item: AnimeListItem, ratingNumberFormatter: NumberFormatter) {
        if !item.imageUrl.isEmpty {
            self.posterImageView.kf.setImage(with: URL(string: item.imageUrl), placeholder: UIImage.placeholder)
        } else {
            self.posterImageView.image = UIImage.placeholder
        }

        self.titleLabel.text = item.animeTitle

        if item.hasRating, let ratingText = ratingNumberFormatter.string(from: NSNumber(value: item.rating)) {
            ratingBadge.text = "  ⭐ " + ratingText + "  "
            ratingBadge.isHidden = false
        } else {
            ratingBadge.isHidden = true
        }

        if item.isOnAir {
            statusLabel.text = NSLocalizedString("连载中", comment: "")
        } else {
            statusLabel.text = NSLocalizedString("已完结", comment: "")
        }
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.85)

        if !item.typeDescription.isEmpty {
            typeLabel.text = " " + item.typeDescription + " "
            typeLabel.isHidden = false
            // pill 风格：主题色
            typeLabel.textColor = .mainColor
            typeLabel.backgroundColor = UIColor.mainColor.withAlphaComponent(0.12)
            typeLabel.layer.cornerRadius = 5
            typeLabel.layer.masksToBounds = true
            typeLabel.layer.borderWidth = 1
            typeLabel.layer.borderColor = UIColor.mainColor.withAlphaComponent(0.25).cgColor
        } else {
            typeLabel.isHidden = true
        }
    }

    // MARK: Init

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
        contentView.addSubview(textOverlay)

        textOverlay.addSubview(overlayStackView)

        // infoRow 放 status + type
        infoRow.addArrangedSubview(statusLabel)
        infoRow.addArrangedSubview(typeLabel)

        // overlay stack 结构：rating → title → infoRow（子类可 insert 插入）
        overlayStackView.addArrangedSubview(ratingBadge)
        overlayStackView.addArrangedSubview(titleLabel)
        overlayStackView.addArrangedSubview(infoRow)

        // poster 填满整个 cell，高度由 WaterfallLayout 决定
        posterImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 半透明遮罩贴在底部，高度由 StackView 内容撑开
        textOverlay.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        overlayStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-12)
        }

        ratingBadge.snp.makeConstraints { make in
            make.height.equalTo(34)
        }
    }

    // MARK: Estimated Height

    /// 计算瀑布流高度：基础 4:3 比例 + animeId 随机抖动，形成错落
    static func estimatedHeight(for item: AnimeListItem, width: CGFloat) -> CGFloat {
        let seed = abs(item.animeId) % 5
        let baseRatio: CGFloat = 1.22 + CGFloat(seed) * 0.04
        return width * baseRatio
    }
}
