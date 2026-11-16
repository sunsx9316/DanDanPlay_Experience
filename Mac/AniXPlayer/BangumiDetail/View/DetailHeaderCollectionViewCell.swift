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
        iv.layer?.cornerRadius = 8
        iv.layer?.borderWidth = 1
        iv.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        return iv
    }()

    private lazy var ratingBadge: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .systemFont(ofSize: 11, weight: .bold)
        tf.textColor = .white
        tf.alignment = .center
        tf.wantsLayer = true
        tf.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.62).cgColor
        tf.layer?.cornerRadius = 5
        tf.layer?.masksToBounds = true
        return tf
    }()

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .systemFont(ofSize: 25, weight: .bold)
        tf.textColor = .labelColor
        tf.maximumNumberOfLines = 2
        tf.lineBreakMode = .byTruncatingTail
        tf.cell?.wraps = true
        return tf
    }()

    private lazy var originalTitleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .systemFont(ofSize: 12.5)
        tf.textColor = .secondaryLabelColor
        tf.maximumNumberOfLines = 1
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    private lazy var metaLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .systemFont(ofSize: 12)
        tf.textColor = .secondaryLabelColor
        tf.maximumNumberOfLines = 1
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    private lazy var tagsLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .systemFont(ofSize: 12)
        tf.textColor = .tertiaryLabelColor
        tf.maximumNumberOfLines = 1
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    private lazy var summaryLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .systemFont(ofSize: 12.5)
        tf.textColor = .secondaryLabelColor
        tf.maximumNumberOfLines = 4
        tf.lineBreakMode = .byTruncatingTail
        tf.cell?.wraps = true
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
        btn.imagePosition = .imageOnly
        btn.contentTintColor = .mainColor
        return btn
    }()

    private lazy var metadataButton: Button = {
        let btn = Button(
            title: NSLocalizedString("详细信息 ›", comment: ""),
            target: self,
            action: #selector(metadataClicked)
        )
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.contentTintColor = .mainColor
        btn.font = .systemFont(ofSize: 12, weight: .medium)
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
        view.addSubview(originalTitleLabel)
        view.addSubview(metaLabel)
        view.addSubview(tagsLabel)
        view.addSubview(summaryLabel)
        view.addSubview(favoriteButton)
        view.addSubview(metadataButton)

        coverImageView.snp.makeConstraints { make in
            make.leading.equalTo(view).offset(24)
            make.top.equalTo(view).offset(20)
            make.width.equalTo(136)
            make.height.equalTo(190)
        }

        ratingBadge.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView).offset(8)
            make.bottom.equalTo(coverImageView).offset(-8)
            make.height.equalTo(22)
            make.width.greaterThanOrEqualTo(48)
        }

        favoriteButton.snp.makeConstraints { make in
            make.trailing.equalTo(view).offset(-24)
            make.top.equalTo(view).offset(20)
            make.width.height.equalTo(28)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(22)
            make.top.equalTo(view).offset(20)
            make.trailing.equalTo(favoriteButton.snp.leading).offset(-12)
        }

        originalTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }

        metaLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(originalTitleLabel.snp.bottom).offset(8)
        }

        tagsLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(metaLabel.snp.bottom).offset(4)
        }

        summaryLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(tagsLabel.snp.bottom).offset(10)
        }

        metadataButton.snp.makeConstraints { make in
            make.trailing.equalTo(view).offset(-20)
            make.bottom.equalTo(view).offset(-14)
        }
    }

    func configure(with item: BangumiDetail) {
        animeId = item.animeId
        isFavorited = item.isFavorited
        titleLabel.text = item.animeTitle

        if let url = URL(string: item.imageUrl) {
            coverImageView.kf.setImage(with: url)
        } else {
            coverImageView.image = NSImage.safeSystemSymbol("film")
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        let ratingText = formatter.string(from: NSNumber(value: item.rating)) ?? "\(item.rating)"
        ratingBadge.text = "  \(ratingText)  "
        ratingBadge.isHidden = item.rating <= 0

        let originalTitle = item.titles
            .first(where: { !$0.title.isEmpty && $0.title != item.animeTitle })?
            .title
        originalTitleLabel.stringValue = originalTitle ?? ""
        originalTitleLabel.isHidden = originalTitle == nil

        var metaParts: [String] = []
        metaParts.append(item.isOnAir
            ? NSLocalizedString("连载中", comment: "")
            : NSLocalizedString("已完结", comment: ""))
        if !item.typeDescription.isEmpty {
            metaParts.append(item.typeDescription)
        }
        if !item.episodes.isEmpty {
            metaParts.append(String(
                format: NSLocalizedString("%d 集", comment: ""),
                item.episodes.count
            ))
        }
        metaLabel.stringValue = metaParts.joined(separator: "  ·  ")
        metaLabel.textColor = item.isOnAir ? .mainColor : .secondaryLabelColor

        let tagText = item.tags
            .sorted(by: { $0.count > $1.count })
            .prefix(6)
            .map { $0.name }
            .joined(separator: "  ·  ")
        tagsLabel.stringValue = tagText
        tagsLabel.isHidden = tagText.isEmpty

        let summary = item.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let intro = item.intro.trimmingCharacters(in: .whitespacesAndNewlines)
        summaryLabel.stringValue = summary.isEmpty ? intro : summary
        summaryLabel.isHidden = summaryLabel.stringValue.isEmpty

        let symbolName = item.isFavorited ? "heart.fill" : "heart"
        favoriteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        favoriteButton.contentTintColor = .mainColor
        favoriteButton.toolTip = item.isFavorited
            ? NSLocalizedString("取消关注", comment: "")
            : NSLocalizedString("关注", comment: "")
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
