//
//  UIView+Helper.swift
//  Runner
//
//  Created by JimHuang on 2020/7/12.
//

import UIKit

extension UIView {

    static func getNib() -> UINib {
        return UINib(nibName: "\(self)", bundle: Bundle(for: self))
    }

    static func fromNib() -> Self {
        let nib = getNib()
        return nib.instantiate(withOwner: nil, options: nil).first as! Self
    }
}
