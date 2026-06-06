//
//  AddFilterTableViewCell.swift
//  AniXPlayer
//
//  tvOS 弹幕过滤「添加」Cell — 主题色标题
//

import UIKit

class AddFilterTableViewCell: TableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textLabel?.text = NSLocalizedString("添加屏蔽弹幕", comment: "")
        textLabel?.font = .ddp_small(weight: .medium)
        textLabel?.textColor = .systemBlue
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
