//
//  UIView+Helper.swift
//  Runner
//
//  Created by JimHuang on 2020/7/12.
//

import UIKit
import MBProgressHUD

extension UIView {
    static func fromNib() -> Self {
        let nib = UINib(nibName: "\(self)", bundle: Bundle(for: self))
        return nib.instantiate(withOwner: nil, options: nil).first as! Self
    }
    
    func showHUD(_ text: String) {
        let view = MBProgressHUD(view: self)
        view.mode = .text
        view.label.text = text
        view.show(animated: true)
        view.hide(animated: true, afterDelay: 1.3)
    }
}
