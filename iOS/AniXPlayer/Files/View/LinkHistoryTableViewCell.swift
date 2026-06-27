//
//  LinkHistoryTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/29.
//

import UIKit
import SnapKit

class LinkHistoryTableViewCell: TableViewCell {

    lazy var nameLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    lazy var addressLabel: Label = {
        let label = Label()
        label.font = .ddp_small
        label.textColor = .lightGray
        label.numberOfLines = 0
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    lazy var remarkLabel: Label = {
        let label = Label()
        label.font = .ddp_small
        label.textColor = .lightGray
        label.numberOfLines = 0
        return label
    }()

    private lazy var topRow: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [nameLabel, addressLabel])
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 8
        return stack
    }()

    private lazy var rootStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [topRow, remarkLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 4
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(rootStack)
        rootStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.equalToSuperview().offset(-10)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.nameLabel.text = nil
        self.addressLabel.text = nil
        self.remarkLabel.text = nil
        self.nameLabel.isHidden = false
    }

}
