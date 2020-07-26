//
//  UIColor+Helper.swift
//  Runner
//
//  Created by JimHuang on 2020/7/12.
//

import UIKit
import YYCategories

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int, alpha: CGFloat = 1) {

        let normalizedRed = CGFloat(red) / 255
        let normalizedGreen = CGFloat(green) / 255
        let normalizedBlue = CGFloat(blue) / 255

        self.init(red: normalizedRed, green: normalizedGreen, blue: normalizedBlue, alpha: alpha)
    }
    
    static var mainColor: UIColor {
        return #colorLiteral(red: 0.9529411765, green: 0.462745098, blue: 0.1843137255, alpha: 1)
    }
}
