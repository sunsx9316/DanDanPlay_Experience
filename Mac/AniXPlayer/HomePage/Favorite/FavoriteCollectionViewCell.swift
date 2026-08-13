//
//  FavoriteCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import Kingfisher

class FavoriteCollectionViewCell: AnimeListCollectionViewCell {

    private lazy var lastWatchLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .subtitleTextColor
        return tf
    }()

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

    override func viewDidLoad() {
        super.viewDidLoad()

        // 向 infoStackView 插入最后观看标签
        infoStackView.addArrangedSubview(lastWatchLabel)
    }

    func configure(with item: UserFavoriteItem) {
        update(item: item, ratingNumberFormatter: ratingFormatter)

        if let lastWatch = item.lastWatchTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            lastWatchLabel.text = String(format: NSLocalizedString("上次观看: %@", comment: ""), formatter.string(from: lastWatch))
            lastWatchLabel.isHidden = false
        } else {
            lastWatchLabel.isHidden = true
        }
    }
}
