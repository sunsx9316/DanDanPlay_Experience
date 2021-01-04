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
    
    @discardableResult func showHUD(_ text: String) -> MBProgressHUD {
        let view = self.createHUD()
        view.mode = .text
        view.label.text = text
        view.hide(animated: true, afterDelay: 1.3)
        return view
    }
    
    func showProgress() -> MBProgressHUD {
        let view = self.createHUD()
        view.mode = .determinateHorizontalBar
        return view
    }
    
    private func createHUD() -> MBProgressHUD {
        let view = MBProgressHUD.showAdded(to: self, animated: true)
        view.bezelView.color = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        view.bezelView.style = .solidColor
        view.label.font = .ddp_normal
        view.contentColor = .white
        view.isUserInteractionEnabled = true
        return view
    }
}
