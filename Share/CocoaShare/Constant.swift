//
//  Constant.swift
//  Runner
//
//  Created by JimHuang on 2020/3/11.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

//public enum WebDavKey: String {
//    case url
//    case user = "web_dav_user"
//    case password = "web_dav_password"
//}


/// 认证信息
struct Auth: Codable, Equatable {
    let userName: String?
    
    let password: String?
    
    init(userName: String?, password: String?) {
        self.userName = userName
        self.password = password
    }
}


/// 登录信息
struct LoginInfo: Codable, Equatable {
    
    var url: URL
    
    var auth: Auth?
    
}


/// 文件筛选类型
struct URLFilterType: OptionSet {
    let rawValue: Int
    
    static let video = URLFilterType(rawValue: 1 << 0)
    static let subtitle = URLFilterType(rawValue: 1 << 1)
    static let danmaku = URLFilterType(rawValue: 1 << 2)
    
    static let all: URLFilterType = [.video, .subtitle, .danmaku]
}

//默认请求域名
let DefaultHost = "https://api.dandanplay.net"

extension NSNotification.Name {
    static let AnixUserLoginStateDidChange = NSNotification.Name(rawValue: "userLoginStateDidChange")
}
