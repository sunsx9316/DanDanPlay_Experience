//
//  TitleTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/5.
//

import UIKit

class TitleTableViewCell: TableViewCell {

    var icon: UIImage? {
        didSet {
            iconImageView.image = icon?.withRenderingMode(.alwaysTemplate)
            iconImageView.isHidden = icon == nil
        }
    }

    private let iconSize: CGFloat = 24

    lazy var label: Label = {
        let label = Label()
        label.numberOfLines = 0
        return label
    }()

    private lazy var iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    private lazy var stackView: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [label, iconImageView])
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 8
        return sv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(15)
            make.trailing.lessThanOrEqualToSuperview().offset(-15)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }

        iconImageView.tintColor = .textColor
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(iconSize)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        icon = nil
    }
}
