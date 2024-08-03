//
//  NSView+HUD.swift
//  ProgressHUD
//
//  Created by jimhuang on 2024/6/27.
//

import Foundation

public class ProgressHUDBuilder {
    
    public var progress: CGFloat = 0 {
        didSet {
            self.view?.setup()
            ProgressHUD.show(progress: progress)
        }
    }
    
    public var statusText: String? {
        didSet {
            self.view?.setup()
            ProgressHUD.setStatus(statusText ?? "")
        }
    }
    
    private weak var view: NSView?
    
    fileprivate init(view: NSView) {
        self.view = view
    }
}

extension NSView {
    
    public func showLoading(statusText: String) {
        setup()
        ProgressHUD.show(withStatus: statusText)
    }
    
    public func showProgress() -> ProgressHUDBuilder {
        return ProgressHUDBuilder(view: self)
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
    
    fileprivate func setup() {
        ProgressHUD.setDefaultStyle(.dark)
        ProgressHUD.setContainerView(self.window?.contentView)
    }
    
}
