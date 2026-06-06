//
//  Button.swift
//  AniXPlayer
//
//  tvOS Button 基类 — 焦点时缩放 + 阴影
//

import UIKit

class Button: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 不调用 super，防止 UIButton 施加 tvOS 系统默认白色焦点外观

        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.0, y: 1.1)
                self.layer.shadowColor = UIColor.white.cgColor
                self.layer.shadowOpacity = 0.3
                self.layer.shadowRadius = 10
                self.layer.shadowOffset = .zero
                self.layer.borderWidth = 3
                self.layer.borderColor = UIColor.mainColor.cgColor
            } else {
                self.transform = .identity
                self.layer.shadowOpacity = 0
                self.layer.borderWidth = 0
                self.layer.borderColor = UIColor.clear.cgColor
            }
        })
    }
}
