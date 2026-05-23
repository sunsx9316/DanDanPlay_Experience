//
//  UIColor+Adaptive.swift
//  AniXPlayer
//
//  tvOS 自适应颜色 — tvOS 不支持 systemBackground，用 dynamic provider 替代
//

import UIKit

extension UIColor {

    /// 自适应背景色（深色模式≈黑，浅色模式≈白）
    static let adaptiveBackground: UIColor = {
        return UIColor(dynamicProvider: { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 0.07, alpha: 1.0)
                : UIColor(white: 0.93, alpha: 1.0)
        })
    }()

    /// 自适应次级背景色（Cell 聚焦高亮，浅色模式用更深的灰保证文字可读）
    static let adaptiveSecondaryBackground: UIColor = {
        return UIColor(dynamicProvider: { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 0.22, alpha: 1.0)
                : UIColor(white: 0.65, alpha: 1.0)
        })
    }()
}
