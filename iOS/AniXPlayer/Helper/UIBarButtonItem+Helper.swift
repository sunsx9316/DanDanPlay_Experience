//
//  UIBarButtonItem+Helper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/12.
//

import UIKit
                                      
extension UIBarButtonItem {
    
    convenience init(title: String, target: Any, action: Selector) {
        self.init(title: title, style: .plain, target: target, action: action)
        self.setTitleTextAttributes([.font : UIFont.ddp_normal,
                                                   .foregroundColor : UIColor.navItemColor], for: .normal)
        self.setTitleTextAttributes([.font : UIFont.ddp_normal,
                                                   .foregroundColor : UIColor.black], for: .highlighted)
    }
    
    convenience init(imageName: String, target: Any, action: Selector) {
        let img = UIImage(named: imageName)?.byTintColor(.navItemColor)?.withRenderingMode(.alwaysOriginal)
        self.init(image: img, style: .plain, target: target, action: action)
    }
    
    convenience init(backToTopItem withTarget: Any, action: Selector) {
        let button = Button()
        let img = UIImage(named: "Public/go_root")?.byTintColor(.navItemColor)
        button.setImage(img, for: .normal)
        button.addTarget(withTarget, action: action, for: .touchUpInside)
        self.init(customView: button)
    }
    
}
