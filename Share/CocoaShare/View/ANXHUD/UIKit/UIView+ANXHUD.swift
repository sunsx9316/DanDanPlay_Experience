//
//  UIView+ANXHUD.swift
//  AniXPlayer
//
//  UIView HUD 便捷扩展（iOS + tvOS）
//

#if os(iOS) || os(tvOS)

import UIKit

enum HUDPosition {
    case center
    case topLeft
    case topRight
    case bottomRight
    case bottomleft
}

extension UIView {

    @discardableResult func showHUD(_ text: String, position: HUDPosition = .center) -> ANXHUD {
        let hud = createHUD(at: position)
        hud.mode = .text
        hud.label.text = text
        hud.hide(animated: true, afterDelay: 2)
        return hud
    }

    func showError(_ error: Error) {
        showHUD(error.localizedDescription)
    }

    @discardableResult func showProgress() -> ANXHUD {
        let hud = createHUD(at: .center)
        hud.mode = .determinateHorizontalBar
        return hud
    }

    @discardableResult func showLoading() -> ANXHUD {
        let hud = createHUD(at: .center)
        hud.mode = .indeterminate
        return hud
    }

    // MARK: Private

    private func createHUD(at position: HUDPosition) -> ANXHUD {
        let hud = ANXHUD.showAdded(to: self, animated: true)
        hud.bezelView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        hud.bezelView.style = .solidColor
        hud.label.font = .ddp_normal
        hud.label.numberOfLines = 0
        hud.contentColor = .white
        hud.isUserInteractionEnabled = true

        switch position {
        case .center:
            break
        case .topLeft:
            hud.offset = .init(x: -3000, y: -3000)
        case .topRight:
            hud.offset = .init(x: -3000, y: 3000)
        case .bottomRight:
            hud.offset = .init(x: 3000, y: 3000)
        case .bottomleft:
            hud.offset = .init(x: -3000, y: 3000)
        }

        return hud
    }
}

#endif
