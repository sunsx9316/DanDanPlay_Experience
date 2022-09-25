//
//  Constant.swift
//  Runner
//
//  Created by JimHuang on 2020/3/11.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//


#if os(iOS)
import UIKit
typealias ANXColor = UIColor
typealias ANXView = UIView
typealias ANXImage = UIImage
typealias ANXViewController = UIViewController
#else
import Cocoa
typealias ANXColor = NSColor
typealias ANXView = NSView
typealias ANXImage = NSImage
typealias ANXViewController = NSViewController
#endif

enum MessageType: String {
    case loadDanmaku = "LoadDanmakuMessage"
    case HUDMessage = "HUDMessage"
    case syncSetting = "SyncSettingMessage"
    case loadFiles = "LoadFilesMessage"
    case appVersion = "AppVersionMessage"
    case inputDanmaku = "InputDanmakuMessage"
    case reloadMatch = "ReloadMatchWidgetMessage"
    case loadCustomDanmaku = "LoadCustomDanmakuMessage"
    //iOS only
    case naviBack = "NaviBackMessage"
    //mac only
    case becomeKeyWindow = "BecomeKeyWindowMessage"
}

public enum WebDavKey: String {
    case url
    case user = "web_dav_user"
    case password = "web_dav_password"
}

protocol DefaultValue {
    associatedtype Value: Any
    static var defaultValue: Value { get }
}

@propertyWrapper
struct Default<T: DefaultValue> {
    var wrappedValue: T.Value
}

struct Auth: Codable, Equatable {
    let userName: String?
    
    let password: String?
    
    init(userName: String?, password: String?) {
        self.userName = userName
        self.password = password
    }
}

struct LoginInfo: Codable, Equatable {
    
    var url: URL
    
    var auth: Auth?
    
}

struct URLFilterType: OptionSet {
    let rawValue: Int
    
    static let video = URLFilterType(rawValue: 1 << 0)
    static let subtitle = URLFilterType(rawValue: 1 << 1)
    static let danmaku = URLFilterType(rawValue: 1 << 2)
    
    static let all: URLFilterType = [.video, .subtitle, .danmaku]
}

//默认请求域名
let DefaultHost = "https://api.dandanplay.net"
