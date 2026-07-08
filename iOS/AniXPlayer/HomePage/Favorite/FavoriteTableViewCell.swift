//
//  FavoriteTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/8.
//

import UIKit

extension UserFavoriteItem: AnimeListItem {
    var typeDescription: String { type.displayName }
    var isFavorited: Bool { favoriteStatus == .favorited }
}

class FavoriteTableViewCell: AnimeListTableViewCell {

    lazy var lastWatchTimeLabel: Label = {
        let label = Label()
        return label
    }()

    lazy var progressLabel: Label = {
        let label = Label()
        return label
    }()

    override var item: AnimeListItem? {
        didSet {
            guard let item = item as? UserFavoriteItem else { return }

            if let lastWatchTime = item.lastWatchTime {
                self.lastWatchTimeLabel.text = NSLocalizedString("上次观看时间：", comment: "") + dateFormatter.string(from: lastWatchTime)
            } else {
                self.lastWatchTimeLabel.text = nil
            }

            self.progressLabel.text = String(format: NSLocalizedString("进度: %d/%d 集", comment: ""), item.episodeWatched, item.episodeTotal)
        }
    }

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.lastWatchTimeLabel.font = .ddp_small
        self.lastWatchTimeLabel.textColor = .subtitleTextColor
        self.progressLabel.font = .ddp_small
        self.progressLabel.textColor = .subtitleTextColor

        // 插入到 typeLabel 之前（typeLabel 目前在 infoStackView 的 index 2）
        infoStackView.insertArrangedSubview(lastWatchTimeLabel, at: 2)
        infoStackView.insertArrangedSubview(progressLabel, at: 3)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
