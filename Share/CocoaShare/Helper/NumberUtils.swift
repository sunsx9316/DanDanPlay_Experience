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
    
    /// 数字转中文
    /// - Parameter number: 数字
    /// - Returns: 中文
    static func numberToChinese(_ number: Int) -> String {
        let chineseNumbers = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        let units = ["", "十", "百", "千", "万", "十", "百", "千", "亿"]
        
        var num = number
        var result = ""
        var unitPosition = 0
        var lastDigit = 0

        while num > 0 {
            let digit = num % 10
            
            if digit == 0 {
                if !result.hasPrefix(chineseNumbers[0]) && !result.isEmpty {
                    result = chineseNumbers[0] + result
                }
            } else {
                let unit = (unitPosition > 0 && digit == 1 && unitPosition == 1 && lastDigit == 0) ? "" : chineseNumbers[digit]
                result = unit + units[unitPosition] + result
            }
            
            lastDigit = digit
            num /= 10
            unitPosition += 1
        }
        
        if result.hasPrefix("一十") {
            result = String(result.dropFirst(1))
        }
        
        return result
    }
}
