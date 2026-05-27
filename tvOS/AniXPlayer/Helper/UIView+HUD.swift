//
//  UIView+HUD.swift
//  AniXPlayer
//
//  tvOS 轻量 HUD 提示
//

import UIKit

private var hudTag: UInt8 = 0

extension UIView {

    private var hudView: UIView? {
        get { return objc_getAssociatedObject(self, &hudTag) as? UIView }
        set { objc_setAssociatedObject(self, &hudTag, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func anx_showLoading(_ message: String? = nil) {
        anx_hideHUD()

        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlay.layer.cornerRadius = 12
        overlay.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(stack)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        stack.addArrangedSubview(spinner)

        if let message = message, !message.isEmpty {
            let label = UILabel()
            label.text = message
            label.font = .ddp_small
            label.textColor = .white
            label.textAlignment = .center
            stack.addArrangedSubview(label)
        }

        addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -24)
        ])

        hudView = overlay
    }

    func anx_hideHUD() {
        hudView?.removeFromSuperview()
        hudView = nil
    }

    func anx_showSuccess(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
        findViewController()?.present(alert, animated: true)
    }

    func anx_showError(_ message: String) {
        let alert = UIAlertController(title: NSLocalizedString("错误", comment: ""), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
        findViewController()?.present(alert, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}
