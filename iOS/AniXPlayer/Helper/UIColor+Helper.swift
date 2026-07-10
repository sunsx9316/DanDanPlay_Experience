//
//  UIColor+Helper.swift
//  Runner
//
//  Created by JimHuang on 2020/7/12.
//

import UIKit

extension UIColor {

    // MARK: Asset Catalog 色表

    private static func byName(_ name: String) -> UIColor {
        if let color = UIColor(named: name) {
            return color
        }
        assert(false, "未找到颜色 \(name)")
        return .white
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

    static var navigationTitleColor: UIColor {
        return .byName("Color/navItemColor")
    }

    static var cellHighlightColor: UIColor {
        return .byName("Color/cellHighlightColor")
    }

    // MARK: 通用色

    static var subtitleTextColor: UIColor {
        return .lightGray
    }

    static var placeholderColor: UIColor {
        return .init(red: 240, green: 240, blue: 240)
    }

    static var shadowColor: UIColor {
        return UIColor { $0.userInterfaceStyle == .dark ? UIColor.black : UIColor.white }
    }
}
