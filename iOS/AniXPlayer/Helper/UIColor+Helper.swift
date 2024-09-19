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
    
    private static func byName(_ name: String) -> UIColor {
        if let color = UIColor(named: name) {
            return color
        }
        assert(false, "未找到颜色 \(name)")
        return .white
    }
    
    static var mainColor: UIColor {
        return UIColor(red: 20, green: 180, blue: 9, alpha: 1)
    }
    
    static var backgroundColor: UIColor {
        return .byName("Color/backgroundColor")
    }
    
    static var navItemColor: UIColor {
        return .byName("Color/navItemColor")
    }
    
    static var headViewBackgroundColor: UIColor {
        return .byName("Color/headViewBackgroundColor")
    }
    
    static var separatorColor: UIColor {
        return .byName("Color/separatorColor")
    }
    
    static var textColor: UIColor {
        return .byName("Color/textColor")
    }
    
    static var indicatorColor: UIColor {
        return .byName("Color/indicatorColor")
    }
    
    static var subtitleTextColor: UIColor {
        return .lightGray
    }
    
    static var navigationTitleColor: UIColor {
        return .byName("Color/navItemColor")
    }
    
    static var placeholderColor: UIColor {
        return .init(red: 240, green: 240, blue: 240)
    }
    
    static var cellHighlightColor: UIColor {
        return .byName("Color/cellHighlightColor")
    }
    
    static var shadowColor: UIColor {
        return UIColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
}
