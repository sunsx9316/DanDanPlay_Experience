//
//  TitleMoreTableViewCell.swift
//  AniXPlayer
//
//  tvOS TitleMoreTableViewCell 基类
//

import UIKit
import SnapKit

class TitleMoreTableViewCell: TableViewCell {

    static let reuseIdentifier = "TitleMoreTableViewCell"

    lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = .adaptiveText
        label.font = .ddp_normal()
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        accessoryType = .disclosureIndicator
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview()
        }
    }
}