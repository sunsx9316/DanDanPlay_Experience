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
                                                   .foregroundColor : UIColor.navigationTitleColor], for: .normal)
        self.setTitleTextAttributes([.font : UIFont.ddp_normal,
                                                   .foregroundColor : UIColor.black], for: .highlighted)
    }
    
    convenience init(imageName: String, target: Any, action: Selector) {
        let img = UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal)
        self.init(image: img, style: .plain, target: target, action: action)
    }
    
    convenience init(backToTopItem withTarget: Any, action: Selector) {
        let button = Button()
        button.setImage(UIImage(named: "Comment/comment_back_to_top"), for: .normal)
        button.addTarget(withTarget, action: action, for: .touchUpInside)
        self.init(customView: button)
    }
    
}
