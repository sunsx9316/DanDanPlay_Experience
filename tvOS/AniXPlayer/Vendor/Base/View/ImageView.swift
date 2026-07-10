//
//  ImageView.swift
//  AniXPlayer
//
//  tvOS ImageView 基类 — Focus Engine 适配
//

import UIKit

class ImageView: UIImageView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    override init(image: UIImage?) {
        super.init(image: image)
        setup()
    }

    override init(image: UIImage?, highlightedImage: UIImage?) {
        super.init(image: image, highlightedImage: highlightedImage)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentMode = .scaleAspectFill
        clipsToBounds = true
    }
}
