//
//  NumberUtils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/11/1.
//

import Foundation


/// 数字工具类
class NumberUtils {
    
    /// 小数转分数
    /// - Parameters:
    ///   - x0: 小数
    ///   - eps: 精度
    static func conver(approximating x0: Double, withPrecision eps: Double = 1.0E-6) -> (numerator: Int, denominator: Int) {
        var x = x0
        var a = x.rounded(.down)
        var (h1, k1, h, k) = (1, 0, Int(a), 1)

        while x - a > eps * Double(k) * Double(k) {
            x = 1.0/(x - a)
            a = x.rounded(.down)
            (h1, k1, h, k) = (h, k, h1 + Int(a) * h, k1 + Int(a) * k)
        }
        return (numerator: h, denominator: k)
    }
}
