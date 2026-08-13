//
//  RelatedAnimeCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit
import Kingfisher

class RelatedAnimeCollectionViewCell: CollectionViewItem {

    var onFavoriteToggle: ((Int, Bool) -> Void)?

    private var animeId: Int = 0
    private var isFavorited: Bool = false

    private lazy var coverImageView: ImageView = {
        let iv = ImageView()
        iv.setScaling(.aspectFill)
        iv.wantsLayer = true
        iv.layer?.masksToBounds = true
        iv.layer?.cornerRadius = 4
        return iv
    }()

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .textColor
        tf.lineBreakMode = .byTruncatingTail
        tf.maximumNumberOfLines = 2
        return tf
    }()

    private lazy var ratingLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small(weight: .bold)
        tf.textColor = .mainColor
        return tf
    }()

    private lazy var favoriteButton: Button = {
        let btn = Button(
            image: NSImage.safeSystemSymbol("heart"),
            target: self,
            action: #selector(favoriteClicked)
        )
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.contentTintColor = .mainColor
        return btn
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(coverImageView)
        view.addSubview(titleLabel)
        view.addSubview(ratingLabel)
        view.addSubview(favoriteButton)

        coverImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(coverImageView.snp.width).multipliedBy(1.4)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(coverImageView.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().offset(-4)
        }

        ratingLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.bottom.equalToSuperview().offset(-4)
        }

        favoriteButton.snp.makeConstraints { make in
            make.leading.equalTo(ratingLabel.snp.trailing).offset(4)
            make.centerY.equalTo(ratingLabel)
            make.width.height.equalTo(16)
        }
    }

    func configure(with item: BangumiIntro) {
        animeId = item.animeId
        isFavorited = item.isFavorited
        titleLabel.text = item.animeTitle

        if let url = URL(string: item.imageUrl) {
            coverImageView.kf.setImage(with: url)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        ratingLabel.text = formatter.string(from: NSNumber(value: item.rating)) ?? "\(item.rating)"

        let symbolName = item.isFavorited ? "heart.fill" : "heart"
        favoriteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    static func estimatedHeight(for item: BangumiIntro, width: CGFloat) -> CGFloat {
        let imageHeight = width * 1.4
        let titleHeight = item.animeTitle.boundingRect(
            with: NSSize(width: width - 8, height: 34),
            options: .usesLineFragmentOrigin,
            attributes: [.font: NSFont.ddp_small()]
        ).height.rounded(.up)
        return 4 + imageHeight + 4 + titleHeight + 2 + 16 + 4
    }

    @objc private func favoriteClicked() {
        let newState = !isFavorited
        isFavorited = newState
        let symbolName = newState ? "heart.fill" : "heart"
        favoriteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        onFavoriteToggle?(animeId, newState)
    }
}
