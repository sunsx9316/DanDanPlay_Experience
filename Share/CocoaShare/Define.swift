//
//  Define.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/6/26.
//

import Foundation

#if os(iOS)
import UIKit
typealias ANXColor = UIColor
typealias ANXView = UIView
typealias ANXImage = UIImage
typealias ANXViewController = UIViewController
typealias ANXFont = UIFont
#else
import Cocoa
typealias ANXColor = NSColor
typealias ANXView = NSView
typealias ANXImage = NSImage
typealias ANXViewController = NSViewController
typealias ANXFont = NSFont
#endif


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
    
    enum Key: String {
        case webDavRootPath = "webDavRootPath"
    }
    
    var url: URL
    
    var auth: Auth?
    
    var parameter: [String: String]?
}


/// 文件筛选类型
struct URLFilterType: OptionSet {
    let rawValue: Int
    
    static let video = URLFilterType(rawValue: 1 << 0)
    static let subtitle = URLFilterType(rawValue: 1 << 1)
    static let danmaku = URLFilterType(rawValue: 1 << 2)
    
    static let all: URLFilterType = [.video, .subtitle, .danmaku]
}

/// 屏蔽弹幕
struct FilterDanmaku: Codable, Equatable {
    var isRegularExp: Bool
    var text: String?
    var isEnable: Bool
}

//默认请求域名
let DefaultHost = "https://api.dandanplay.net"
