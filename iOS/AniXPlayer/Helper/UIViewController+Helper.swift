//
//  UIViewController+Helper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/10/20.
//

import UIKit

extension UIViewController {
    func present(_ viewControllerToPresent: UIViewController, atView view: UIView?, sourceRect: CGRect? = nil, completion: (() -> Void)? = nil) {
        // iPhone Duo 内屏、iPad 分屏等宽窗口用 popover，窄窗口仍用 sheet
        if traitCollection.horizontalSizeClass == .regular, let view = view {
            viewControllerToPresent.modalPresentationStyle = .popover
            viewControllerToPresent.popoverPresentationController?.sourceView = view
            if let sourceRect = sourceRect {
                viewControllerToPresent.popoverPresentationController?.sourceRect = sourceRect
            }
        }
        self.present(viewControllerToPresent, animated: true, completion: completion)
    }

    func present(_ viewControllerToPresent: UIViewController, atItem item: UIBarButtonItem?, completion: (() -> Void)? = nil) {
        if traitCollection.horizontalSizeClass == .regular, let item = item {
            viewControllerToPresent.modalPresentationStyle = .popover
            viewControllerToPresent.popoverPresentationController?.barButtonItem = item
        }
        self.present(viewControllerToPresent, animated: true, completion: completion)
    }
}
