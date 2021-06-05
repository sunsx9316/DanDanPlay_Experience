//
//  Comment.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import Foundation
import HandyJSON

#if os(iOS)
typealias Color = UIColor
#else
typealias Color = NSColor
#endif

struct Comment: HandyJSON {
    
    enum Mode: Int, HandyJSONEnum {
        case normal = 1
        case bottom = 4
        case top = 5
    }
    
    var mode = Mode.normal
    
    var time: TimeInterval = 0
    
    var color = DanmakuColor.white
    
    var message = ""
    
    var id = 0
    
    var userId = ""
    
    //    p参数格式为出现时间,模式,颜色,用户ID，各个参数之间使用英文逗号分隔
    //
    //    弹幕出现时间：格式为 0.00，单位为秒，精确到小数点后两位，例如12.34、445.6、789.01
    //    弹幕模式：1-普通弹幕，4-底部弹幕，5-顶部弹幕
    //    颜色：32位整数表示的颜色，算法为 Rx255x255+Gx255+B
    //    用户ID：字符串形式表示的用户ID，通常为数字，不会包含特殊字符
    private var p = ""
    
    
    mutating func mapping(mapper: HelpingMapper) {
        mapper <<<
            self.message <-- "m"
        
        mapper <<<
            self.id <-- "cid"
    }
    
    mutating func didFinishMapping() {
        let parameter = self.p.components(separatedBy: ",")
        
        if parameter.count > 0 {
            self.time = TimeInterval(parameter[0]) ?? 0
        }
        
        if parameter.count > 1 {
            let rawValue = Int(parameter[1]) ?? Mode.normal.rawValue
            self.mode = Mode(rawValue: rawValue) ?? .normal
        }
        
        if parameter.count > 2 {
            let rgb = Int(parameter[2]) ?? 0
            self.color = DanmakuColor(rgb: rgb)
        }
        
        if parameter.count > 3 {
            self.userId = parameter[3]
        }
    }
}


struct CommentCollection: HandyJSON {
    
    var collection = [Comment]()
    
    mutating func mapping(mapper: HelpingMapper) {
        mapper <<<
            self.collection <-- "comments"
    }
}
