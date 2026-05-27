//
//  Label.swift
//  AniXPlayer
//
//  tvOS Label 基类 — 焦点时文字颜色变化
//

import UIKit

class Label: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.textColor = .white
            } else {
                self.textColor = .lightGray
            }
        })
    }
}
