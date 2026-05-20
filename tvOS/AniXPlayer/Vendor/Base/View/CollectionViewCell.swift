//
//  CollectionViewCell.swift
//  AniXPlayer
//
//  tvOS CollectionViewCell 基类 — 焦点时缩放 1.05x + 阴影
//

import UIKit

class CollectionViewCell: UICollectionViewCell {

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    private func setup() {
        self.backgroundColor = .clear
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.layer.shadowColor = UIColor.white.cgColor
                self.layer.shadowOpacity = 0.3
                self.layer.shadowRadius = 10
                self.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.layer.shadowOpacity = 0
            }
        })
    }
}
