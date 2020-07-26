//
//  UIView+Helper.swift
//  Runner
//
//  Created by JimHuang on 2020/7/12.
//

import UIKit

extension UIView {
    static func fromNib() -> Self {
        let nib = UINib(nibName: "\(self)", bundle: Bundle(for: self))
        return nib.instantiate(withOwner: nil, options: nil).first as! Self
    }
}
