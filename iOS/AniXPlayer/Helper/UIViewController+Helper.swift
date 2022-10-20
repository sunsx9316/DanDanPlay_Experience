//
//  UIViewController+Helper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/10/20.
//

import UIKit

extension UIViewController {
    func present(_ viewControllerToPresent: UIViewController, atView view: UIView?, completion: (() -> Void)? = nil) {
        if UIDevice.current.isPad {
            viewControllerToPresent.popoverPresentationController?.sourceView = view
        }
        self.present(viewControllerToPresent, animated: true, completion: nil)
    }
    
    func present(_ viewControllerToPresent: UIViewController, atItem item: UIBarButtonItem?, completion: (() -> Void)? = nil) {
        if UIDevice.current.isPad {
            viewControllerToPresent.popoverPresentationController?.barButtonItem = item
        }
        self.present(viewControllerToPresent, animated: true, completion: nil)
    }
}
