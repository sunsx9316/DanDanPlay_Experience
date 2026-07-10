//
//  TitleTableViewCell.swift
//  AniXPlayer
//
//  tvOS TitleTableViewCell 基类
//

import UIKit
import SnapKit

class TitleTableViewCell: TableViewCell {


    lazy var label: UILabel = {
        let label = Label()
        label.textColor = .adaptiveText
        label.font = .ddp_normal()
        label.numberOfLines = 0
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
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalToSuperview().offset(14)
            make.bottom.equalToSuperview().offset(-14).priority(.high)
        }
    }
}
