//
//  TimelineCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import Kingfisher

class TimelineCollectionViewCell: AnimeListCollectionViewCell {

    private lazy var ratingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.roundingMode = .halfEven
        return f
    }()

    override func loadView() {
        super.loadView()
        view.layer?.backgroundColor = NSColor.backgroundColor.cgColor
    }

    func configure(with item: BangumiIntro) {
        update(item: item, ratingNumberFormatter: ratingFormatter)
    }
}
