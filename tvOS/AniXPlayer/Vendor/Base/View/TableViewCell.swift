//
//  TableViewCell.swift
//  AniXPlayer
//
//  tvOS TableViewCell 基类 — 焦点时主题色描边高亮
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
        self.backgroundColor = .adaptiveBackground
        self.contentView.backgroundColor = .adaptiveSecondaryBackground
        self.layer.cornerRadius = 16
        self.clipsToBounds = true
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 不调用 super，防止 UITableViewCell 施加 tvOS 系统白色焦点背景

        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.backgroundColor = .clear
                self.layer.borderWidth = 4
                self.layer.borderColor = UIColor.mainColor.cgColor
            } else {
                self.backgroundColor = .clear
                self.layer.borderWidth = 0
                self.layer.borderColor = UIColor.clear.cgColor
            }
        }, completion: nil)
    }
}
