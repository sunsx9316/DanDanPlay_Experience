//
//  NSView+HUD.swift
//  ProgressHUD
//
//  Created by jimhuang on 2024/6/27.
//

import Foundation

extension NSView {
    
    public func showLoading(statusText: String) {
        setup()
        ProgressHUD.show(withStatus: statusText)
    }
    
    public func show(progress: Double, statusText: String) {
        setup()
        ProgressHUD.show(progress: progress, status: statusText)
    }
    
    public func show(error: Error) {
        setup()
        ProgressHUD.showErrorWithStatus(error.localizedDescription)
    }
    
    public func show(text: String) {
        setup()
        ProgressHUD.showTextWithStatus(text)
    }
    
    public func dismiss(delay: TimeInterval) {
        ProgressHUD.dismiss(delay: delay)
    }
    
    private func setup() {
        ProgressHUD.setDefaultStyle(.dark)
        ProgressHUD.setContainerView(self.window?.contentView)
    }
    
}
