//
//  PlayerToastView.swift
//  AniXPlayer
//
//  tvOS 轻量 toast 提示
//

import UIKit
import SnapKit

class PlayerToastView: UIView {

    static func show(in view: UIView, text: String, duration: TimeInterval = 1.5) {
        // 移除已有的 toast，避免叠加
        view.subviews.compactMap { $0 as? PlayerToastView }.forEach { $0.removeFromSuperview() }

        let toast = PlayerToastView(text: text)
        view.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        toast.alpha = 0
        toast.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            toast.alpha = 1
            toast.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: .curveEaseIn) {
                toast.alpha = 0
            } completion: { _ in
                toast.removeFromSuperview()
            }
        }
    }

    private let label: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 40, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    private init(text: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0, alpha: 0.6)
        layer.cornerRadius = 16

        label.text = text
        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 32, bottom: 16, right: 32))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
