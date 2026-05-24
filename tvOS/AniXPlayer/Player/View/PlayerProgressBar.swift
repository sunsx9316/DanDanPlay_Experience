//
//  PlayerProgressBar.swift
//  AniXPlayer
//
//  tvOS 通用进度条 — 轨道 + 填充
//

import UIKit
import SnapKit

class PlayerProgressBar: UIView {

    var progressFraction: CGFloat = 0 {
        didSet { updateFill() }
    }

    var fillColor: UIColor = .systemGreen {
        didSet { fillView.backgroundColor = fillColor }
    }

    private let fillView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        return view
    }()

    private var fillWidthConstraint: Constraint?

    // MARK: - Init

    init(trackColor: UIColor, cornerRadius: CGFloat = 0) {
        super.init(frame: .zero)
        backgroundColor = trackColor
        layer.cornerRadius = cornerRadius
        clipsToBounds = true

        addSubview(fillView)
        fillView.layer.cornerRadius = cornerRadius
        fillView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            fillWidthConstraint = make.width.equalTo(0).constraint
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateFill()
    }

    private func updateFill() {
        fillWidthConstraint?.update(offset: bounds.width * progressFraction)
    }
}
