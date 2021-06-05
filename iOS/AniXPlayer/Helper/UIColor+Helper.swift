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
        return UIColor(red: 243, green: 118, blue: 47, alpha: 1)
    }
    
    static var backgroundColor: UIColor {
        return .white
    }
    
    static var headViewBackgroundColor: UIColor {
        return .init(red: 240, green: 240, blue: 240)
    }
    
    static var separatorColor: UIColor {
        return .lightGray
    }
    
    static var textColor: UIColor {
        return .black
    }
    
    static var subtitleTextColor: UIColor {
        return .lightGray
    }
    
    static var navigationTitleColor: UIColor {
        return .white
    }
    
    static var placeholderColor: UIColor {
        return .init(red: 240, green: 240, blue: 240)
    }
    
    static var cellHighlightColor: UIColor {
        return .init(red: 220, green: 220, blue: 220)
    }
}
