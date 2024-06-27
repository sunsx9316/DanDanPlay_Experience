//
//  Comment.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import Foundation

struct Comment: Decodable {
    
    enum Mode: Int, Decodable {
        case normal = 1
        case bottom = 4
        case top = 5
    }
    
    var mode: Mode
    
    var time: TimeInterval
    
    var color: ANXColor
    
    var message: String
    
    var id: Int
    
    var userId: String
    
    //来源
    var source: String

    private enum CodingKeys: String, CodingKey {
        case mode
        case time
        case color 
        case message = "m"
        case id = "cid"
        case userId
        case source
        case p
    }
    
    init() {
        self.time = 0
        self.mode = .normal
        self.color = .white
        self.source = ""
        self.userId = ""
        self.id = 0
        self.message = ""
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.time = 0
        self.mode = .normal
        self.color = .white
        self.source = ""
        self.userId = ""
        self.id = 0
        
        //    p参数格式为出现时间,模式,颜色,[来源]用户ID，各个参数之间使用英文逗号分隔
        //
        //    弹幕出现时间：格式为 0.00，单位为秒，精确到小数点后两位，例如12.34、445.6、789.01
        //    弹幕模式：1-普通弹幕，4-底部弹幕，5-顶部弹幕
        //    颜色：32位整数表示的颜色，算法为 Rx255x255+Gx255+B
        //    用户ID：字符串形式表示的用户ID，通常为数字，不会包含特殊字符
        if let p = try container.decodeIfPresent(String.self, forKey: .p) {
            let parameter = p.components(separatedBy: ",")
            
            if parameter.count > 0 {
                self.time = TimeInterval(parameter[0]) ?? 0
            }
            
            if parameter.count > 1 {
                let rawValue = Int(parameter[1]) ?? Mode.normal.rawValue
                self.mode = Mode(rawValue: rawValue) ?? .normal
            }
            
            if parameter.count > 2 {
                let rgb = Int(parameter[2]) ?? 0
                self.color = ANXColor(rgb: rgb)
            }
            
            if parameter.count > 3 {
                let arr = parameter[3].components(separatedBy: "]")
                if arr.count == 2 {
                    self.source = arr[0].replacingOccurrences(of: "[", with: "")
                    self.userId = arr[1]
                }
            }
        }
        
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
    }
}


struct CommentCollection: Decodable {
    
    @Default<[Comment]> var collection: [Comment]
    
    private enum CodingKeys: String, CodingKey {
        case collection = "comments"
    }
}
