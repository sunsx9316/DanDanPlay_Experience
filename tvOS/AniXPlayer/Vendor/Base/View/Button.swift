//
//  Button.swift
//  AniXPlayer
//
//  tvOS Button 基类 — 焦点时缩放 + 边框
//

import UIKit

class Button: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        self.backgroundColor = .clear
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 不调用 super，防止 UIButton 施加 tvOS 系统默认白色焦点外观

        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.layer.borderWidth = 3
                self.layer.borderColor = UIColor.mainColor.cgColor
            } else {
                self.transform = .identity
                self.layer.borderWidth = 0
                self.layer.borderColor = UIColor.clear.cgColor
            }
        })
    }
}
