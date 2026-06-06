//
//  OptionTableViewCell.swift
//  AniXPlayer
//
//  tvOS 选项选择器 Cell — 自定义选中标记，主题色展示
//

import UIKit

class OptionTableViewCell: TableViewCell {

    private let checkmarkView: UILabel = {
        let label = UILabel()
        label.text = "✓"
        label.font = .boldSystemFont(ofSize: 22)
        label.textColor = .mainColor
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(checkmarkView)
        checkmarkView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, isSelected: Bool) {
        textLabel?.text = title
        textLabel?.font = .ddp_small()
        textLabel?.textColor = .label
        checkmarkView.isHidden = !isSelected
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        checkmarkView.isHidden = true
    }
}
