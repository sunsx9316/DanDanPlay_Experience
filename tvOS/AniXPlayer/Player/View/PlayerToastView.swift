//
//  PlayerToastView.swift
//  AniXPlayer
//
//  tvOS 轻量 toast 提示
//

import UIKit
import SnapKit

class PlayerToastView: UIView {
    
    private var durationTimer: Timer?

    private let label: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .ddp_large(weight: .medium)
        label.textAlignment = .center
        return label
    }()

    @discardableResult static func show(in view: UIView, text: String, dismissAfter duration: TimeInterval? = 0.5) -> PlayerToastView {
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
            if duration != nil {
                toast.dismiss(after: duration)
            }
        }
        
        return toast
    }

    func updateText(_ text: String) {
        label.text = text
    }

    func dismiss(after duration: TimeInterval? = nil) {
        if let duration = duration {
            durationTimer?.invalidate()
            durationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                UIView.animate(withDuration: 0.2) {
                    self?.alpha = 0
                } completion: { _ in
                    self?.removeFromSuperview()
                }
            }
            
        } else {
            UIView.animate(withDuration: 0.15) {
                self.alpha = 0
            } completion: { _ in
                self.removeFromSuperview()
            }
        }
    }

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
    
    deinit {
        durationTimer?.invalidate()
    }
}
