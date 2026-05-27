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
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.layer.cornerRadius = 10
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 不调用 super，防止 UITableViewCell 施加 tvOS 系统白色焦点背景

        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.backgroundColor = .clear
                self.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
                self.layer.borderWidth = 2
                self.layer.borderColor = UIColor.mainColor.cgColor
            } else {
                self.backgroundColor = .clear
                self.transform = .identity
                self.layer.borderWidth = 0
                self.layer.borderColor = UIColor.clear.cgColor
            }
        }, completion: nil)
    }
}
