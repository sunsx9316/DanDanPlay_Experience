//
//  UIFont+Helper.swift
//  AniXPlayer
//
//  tvOS 字体扩展 — 统一字号标准
//

import UIKit

extension UIFont {

    /// 最小字号 24pt — 正文、副标题、按钮
    static func ddp_small(weight: UIFont.Weight = .regular, monospaced: Bool = false) -> UIFont {
        return monospaced
            ? .monospacedDigitSystemFont(ofSize: 24, weight: weight)
            : .systemFont(ofSize: 24, weight: weight)
    }

    /// 中等字号 30pt — 标题、section header
    static func ddp_normal(weight: UIFont.Weight = .regular, monospaced: Bool = false) -> UIFont {
        return monospaced
            ? .monospacedDigitSystemFont(ofSize: 30, weight: weight)
            : .systemFont(ofSize: 30, weight: weight)
    }

    /// 大号 35pt — 页面主标题
    static func ddp_large(weight: UIFont.Weight = .regular, monospaced: Bool = false) -> UIFont {
        return monospaced
            ? .monospacedDigitSystemFont(ofSize: 35, weight: weight)
            : .systemFont(ofSize: 35, weight: weight)
    }
}
