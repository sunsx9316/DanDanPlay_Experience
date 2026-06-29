//
//  NSView+HUD.swift
//  ProgressHUD
//
//  NSView 便捷扩展，内部转调 ProgressHUD
//

import Cocoa

extension NSView {

    // MARK: - Loading

    @discardableResult
    func showLoading(statusText: String) -> ProgressHUD {
        dismiss()
        let hud = ProgressHUD.showAdded(to: self, animated: true)
        hud.mode = .indeterminate
        hud.labelText = statusText
        hud.bezelColor = NSColor.black.withAlphaComponent(0.6)
        hud.contentColor = .white
        hud.removeFromSuperViewOnHide = true
        return hud
    }

    // MARK: - Progress

    @discardableResult
    func showProgress() -> ProgressHUD {
        dismiss()
        let hud = ProgressHUD.showAdded(to: self, animated: true)
        hud.mode = .determinateHorizontalBar
        hud.bezelColor = NSColor.black.withAlphaComponent(0.6)
        hud.contentColor = .white
        hud.removeFromSuperViewOnHide = true
        return hud
    }

    // MARK: - Text / Error

    func show(text: String) {
        dismiss()
        let hud = ProgressHUD.showAdded(to: self, animated: true)
        hud.mode = .text
        hud.labelText = text
        hud.bezelColor = NSColor.black.withAlphaComponent(0.6)
        hud.contentColor = .white
        hud.removeFromSuperViewOnHide = true
        hud.hide(animated: true, afterDelay: 2)
    }

    func show(error: Error) {
        show(text: error.localizedDescription)
    }

    // MARK: - Dismiss

    func dismiss(delay: TimeInterval = 0) {
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                ProgressHUD.hide(for: self, animated: true)
            }
        } else {
            ProgressHUD.hide(for: self, animated: true)
        }
    }
}
