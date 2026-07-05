//
//  QueueItem.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/1.
//

import Cocoa
import SnapKit
import Kingfisher

class QueueItem: CollectionViewItem {

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.cellHighlightColor.cgColor

        view.addSubview(coverImageView)
        view.addSubview(titleLabel)
        view.addSubview(episodeLabel)
        view.addSubview(statusLabel)

        coverImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(coverImageView.snp.width).multipliedBy(1.4)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(coverImageView.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
        }

        episodeLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
        }

        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(episodeLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-8)
        }
    }

    // MARK: - Private

    private let coverImageView: ImageView = {
        let iv = ImageView()
        iv.setScaling(.proportionallyDown)
        return iv
    }()

    private let titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_normal()
        tf.textColor = .textColor
        tf.lineBreakMode = .byTruncatingTail
        tf.maximumNumberOfLines = 2
        return tf
    }()

    private let episodeLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .subtitleTextColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    private let statusLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .mainColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    func configure(with item: BangumiQueueIntro) {
        titleLabel.text = item.animeTitle
        episodeLabel.text = item.episodeTitle
        statusLabel.text = item.description

        if let url = URL(string: item.imageUrl) {
            coverImageView.kf.setImage(with: url)
        }
    }

    static func estimatedHeight(for item: BangumiQueueIntro, width: CGFloat) -> CGFloat {
        let imageHeight = width * 1.4
        let titleHeight = item.animeTitle.boundingRect(
            with: NSSize(width: width - 16, height: 40),
            options: .usesLineFragmentOrigin,
            attributes: [.font: NSFont.ddp_normal()]
        ).height.rounded(.up)
        return imageHeight + 8 + titleHeight + 4 + 18 + 2 + 18 + 8
    }
}
