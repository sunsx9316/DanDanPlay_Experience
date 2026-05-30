//
//  HomePageFunctionCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit

struct HomePageFunctionItem {

    enum ItemType {
        case timeLine
        case favorite
    }

    var itemType: ItemType

    var img: UIImage

    var name: String

}

class HomePageFunctionCollectionViewCell: CollectionViewCell {

    lazy var imgView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    lazy var nameLabel: Label = {
        let label = Label()
        label.textAlignment = .center
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()

    lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 5
        sv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sv.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return sv
    }()

    var item: HomePageFunctionItem? {
        didSet {
            self.imgView.image = self.item?.img
            self.nameLabel.text = self.item?.name
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(stackView)
        stackView.addArrangedSubview(imgView)
        stackView.addArrangedSubview(nameLabel)

        stackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        self.nameLabel.font = .ddp_small
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
