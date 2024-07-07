//
//  UIView+Helper.swift
//  Runner
//
//  Created by JimHuang on 2020/7/12.
//

import UIKit
import MBProgressHUD

enum HUDPosition {
    case center
    case topLeft
    case topRight
    case bottomRight
    case bottomleft
}

extension UIView {
    
    static func getNib() -> UINib {
        return UINib(nibName: "\(self)", bundle: Bundle(for: self))
    }
    
    static func fromNib() -> Self {
        let nib = getNib()
        return nib.instantiate(withOwner: nil, options: nil).first as! Self
    }
    
    @discardableResult func showHUD(_ text: String, position: HUDPosition = .center) -> MBProgressHUD {
        let view = self.createHUD(at: position)
        view.mode = .text
        view.label.text = text
        view.hide(animated: true, afterDelay: 2)
        
        return view
    }
    
    func showError(_ error: Error) {
        self.showHUD(error.localizedDescription)
    }
    
    func showProgress() -> MBProgressHUD {
        let view = self.createHUD(at: .center)
        view.mode = .determinateHorizontalBar
        return view
    }
    
    func showLoading() -> MBProgressHUD {
        let view = self.createHUD(at: .center)
        view.mode = .indeterminate
        return view
    }
    
    private func createHUD(at position: HUDPosition) -> MBProgressHUD {
        let view = MBProgressHUD.showAdded(to: self, animated: true)
        view.bezelView.color = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        view.bezelView.style = .solidColor
        view.label.font = .ddp_normal
        view.label.numberOfLines = 0
        view.contentColor = .white
        view.isUserInteractionEnabled = true
        
        switch position {
        case .center:
            break
        case .topLeft:
            view.offset = .init(x: -3000, y: -3000)
        case .topRight:
            view.offset = .init(x: -3000, y: 3000)
        case .bottomRight:
            view.offset = .init(x: 3000, y: 3000)
        case .bottomleft:
            view.offset = .init(x: -3000, y: 3000)
        }
        
        return view
    }
}
