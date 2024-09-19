//
//  UIViewController+Helper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/10/20.
//

import UIKit

extension UIViewController {
    func present(_ viewControllerToPresent: UIViewController, atView view: UIView?, sourceRect: CGRect? = nil, completion: (() -> Void)? = nil) {
        if UIDevice.current.isPad && view != nil {
            viewControllerToPresent.modalPresentationStyle = .popover
            viewControllerToPresent.popoverPresentationController?.sourceView = view
            if let sourceRect = sourceRect {
                viewControllerToPresent.popoverPresentationController?.sourceRect = sourceRect
            }
        }
        self.present(viewControllerToPresent, animated: true, completion: nil)
    }
    
    func present(_ viewControllerToPresent: UIViewController, atItem item: UIBarButtonItem?, completion: (() -> Void)? = nil) {
        if UIDevice.current.isPad && item != nil {
            viewControllerToPresent.modalPresentationStyle = .popover
            viewControllerToPresent.popoverPresentationController?.barButtonItem = item
        }
        self.present(viewControllerToPresent, animated: true, completion: nil)
    }
}
