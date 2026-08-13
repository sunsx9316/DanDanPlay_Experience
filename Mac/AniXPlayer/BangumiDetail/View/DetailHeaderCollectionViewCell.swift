//
//  DetailHeaderCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit
import Kingfisher

class DetailHeaderCollectionViewCell: CollectionViewItem {

    var onFavoriteToggle: ((Int, Bool) -> Void)?
    var onTapMetadata: (() -> Void)?

    private var animeId: Int = 0
    private var isFavorited: Bool = false

    private lazy var coverImageView: ImageView = {
        let iv = ImageView()
        iv.setScaling(.aspectFill)
        iv.wantsLayer = true
        iv.layer?.masksToBounds = true
        iv.layer?.cornerRadius = 6
        iv.layer?.shadowColor = NSColor.black.cgColor
        iv.layer?.shadowOffset = NSSize(width: 0, height: 2)
        iv.layer?.shadowRadius = 4
        iv.layer?.shadowOpacity = 0.15
        return iv
    }()

    private lazy var ratingBadge: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small(weight: .bold)
        tf.textColor = .white
        tf.alignment = .center
        tf.wantsLayer = true
        tf.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        tf.layer?.cornerRadius = 4
        tf.layer?.masksToBounds = true
        return tf
    }()

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_large(weight: .bold)
        tf.textColor = .textColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    private lazy var statusLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        return tf
    }()

    private lazy var tagsLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .subtitleTextColor
        tf.lineBreakMode = .byTruncatingTail
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

    private lazy var metadataArrow: Button = {
        let btn = Button(
            image: NSImage.safeSystemSymbol("chevron.right"),
            target: self,
            action: #selector(metadataClicked)
        )
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.contentTintColor = .subtitleTextColor
        return btn
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.backgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(coverImageView)
        coverImageView.addSubview(ratingBadge)
        view.addSubview(titleLabel)
        view.addSubview(statusLabel)
        view.addSubview(tagsLabel)
        view.addSubview(favoriteButton)
        view.addSubview(metadataArrow)

        coverImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(15)
            make.width.equalTo(100)
            make.height.equalTo(120)
        }

        ratingBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
            make.height.equalTo(18)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(15)
            make.top.equalTo(coverImageView.snp.top).offset(4)
            make.trailing.equalTo(favoriteButton.snp.leading).offset(-8)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }

        tagsLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(statusLabel.snp.bottom).offset(4)
            make.trailing.equalToSuperview().offset(-80)
        }

        favoriteButton.snp.makeConstraints { make in
            make.trailing.equalTo(metadataArrow.snp.leading).offset(-8)
            make.centerY.equalTo(titleLabel)
            make.width.height.equalTo(24)
        }

        metadataArrow.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }

    func configure(with item: BangumiDetail) {
        animeId = item.animeId
        isFavorited = item.isFavorited
        titleLabel.text = item.animeTitle

        if let url = URL(string: item.imageUrl) {
            coverImageView.kf.setImage(with: url)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        let ratingText = formatter.string(from: NSNumber(value: item.rating)) ?? "\(item.rating)"
        ratingBadge.text = "  \(ratingText)  "
        ratingBadge.isHidden = item.rating <= 0

        statusLabel.text = item.isOnAir ? NSLocalizedString("连载中", comment: "") : NSLocalizedString("已完结", comment: "")
        statusLabel.textColor = item.isOnAir ? .mainColor : .subtitleTextColor

        let tagText = item.tags.sorted(by: { $0.count > $1.count }).prefix(5).map { $0.name }.joined(separator: ", ")
        tagsLabel.text = tagText

        let symbolName = item.isFavorited ? "heart.fill" : "heart"
        favoriteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        favoriteButton.contentTintColor = item.isFavorited ? .mainColor : .mainColor
    }

    @objc private func favoriteClicked() {
        let newState = !isFavorited
        isFavorited = newState
        let symbolName = newState ? "heart.fill" : "heart"
        favoriteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        onFavoriteToggle?(animeId, newState)
    }

    @objc private func metadataClicked() {
        onTapMetadata?()
    }
}
