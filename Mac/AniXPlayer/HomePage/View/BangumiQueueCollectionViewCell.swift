//
//  BangumiQueueCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/1.
//

import Cocoa
import Kingfisher

class BangumiQueueCollectionViewCell: AnimeListCollectionViewCell {

    private lazy var episodeLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .subtitleTextColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    private lazy var statusLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .mainColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // 队列卡片不需要 rating badge / 关注按钮 / 类型标签
        isOnAirLabel.isHidden = true
        typeLabel.isHidden = true
        favoritedButton.isHidden = true

        // 向 infoStackView 插入队列特有的 label
        infoStackView.addArrangedSubview(episodeLabel)
        infoStackView.addArrangedSubview(statusLabel)
    }

    func configure(with item: BangumiQueueIntro) {
        titleLabel.text = item.animeTitle
        episodeLabel.text = item.episodeTitle
        statusLabel.text = item.description

        if let url = URL(string: item.imageUrl) {
            imgView.kf.setImage(with: url)
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
