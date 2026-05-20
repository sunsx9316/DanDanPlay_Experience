//
//  TableViewCell.swift
//  AniXPlayer
//
//  tvOS TableViewCell 基类 — 焦点时背景高亮 + 文字颜色变化
//

import UIKit

class TableViewCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    private func setup() {
        self.backgroundColor = .clear
        self.textLabel?.textColor = .lightGray
        self.detailTextLabel?.textColor = .lightGray
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.backgroundColor = UIColor.white.withAlphaComponent(0.15)
                self.textLabel?.textColor = .white
                self.detailTextLabel?.textColor = .white
            } else {
                self.backgroundColor = .clear
                self.textLabel?.textColor = .lightGray
                self.detailTextLabel?.textColor = .lightGray
            }
        })
    }
}
