//
//  TimelineItemTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit

extension BangumiIntro: AnimeListItem {
    var typeDescription: String { "" }
}

class TimelineItemTableViewCell: AnimeListTableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // 横滑场景不需要 typeLabel
        typeLabel.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
