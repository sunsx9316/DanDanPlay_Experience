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

/// 媒体设置项
enum MediaSettingType: CaseIterable {
    
    case matchInfo
    
    case playerSpeed
    case subtitleMargin
    case subtitleFontSize
    
    case autoJumpTitleEnding
    case jumpTitleDuration
    case jumpEndingDuration
    
    case playerMode
    case subtitleTrack
    case audioTrack
    case subtitleSafeArea
    case subtitleDelay
    case loadSubtitle
    
    
    var title: String {
        switch self {
        case .subtitleSafeArea:
            return NSLocalizedString("防挡字幕", comment: "")
        case .playerSpeed:
            return NSLocalizedString("播放速度", comment: "")
        case .playerMode:
            return NSLocalizedString("播放模式", comment: "")
        case .loadSubtitle:
            return NSLocalizedString("加载字幕...", comment: "")
        case .subtitleTrack:
            return NSLocalizedString("字幕轨道", comment: "")
        case .audioTrack:
            return NSLocalizedString("音频轨道", comment: "")
        case .autoJumpTitleEnding:
            return NSLocalizedString("自动跳过片头/片尾", comment: "")
        case .jumpTitleDuration:
            return NSLocalizedString("跳过片头时长", comment: "")
        case .jumpEndingDuration:
            return NSLocalizedString("跳过片尾时长", comment: "")
        case .subtitleDelay:
            return NSLocalizedString("字幕时间偏移", comment: "")
        case .subtitleMargin:
            return NSLocalizedString("字幕Y轴偏移", comment: "")
        case .subtitleFontSize:
            return NSLocalizedString("字幕大小", comment: "")
        case .matchInfo:
            return NSLocalizedString("弹幕信息", comment: "")
        }
    }
}


/// 弹幕设置项
enum DanmakuSettingType: CaseIterable {
    case danmakuFontSize
    case danmakuSpeed
    case danmakuAlpha
    case danmakuDensity
    
    case danmakuArea
    case showDanmaku
    case mergeSameDanmaku
    
    case danmakuOffsetTime
    case searchDanmaku
    case loadDanmaku
    
    var title: String {
        switch self {
        case .danmakuFontSize:
            return NSLocalizedString("弹幕字体大小", comment: "")
        case .danmakuSpeed:
            return NSLocalizedString("弹幕速度", comment: "")
        case .danmakuAlpha:
            return NSLocalizedString("弹幕透明度", comment: "")
        case .danmakuArea:
            return NSLocalizedString("显示区域", comment: "")
        case .showDanmaku:
            return NSLocalizedString("弹幕开关", comment: "")
        case .danmakuOffsetTime:
            return NSLocalizedString("弹幕偏移时间", comment: "")
        case .loadDanmaku:
            return NSLocalizedString("加载本地弹幕...", comment: "")
        case .searchDanmaku:
            return NSLocalizedString("搜索弹幕", comment: "")
        case .danmakuDensity:
            return NSLocalizedString("弹幕密度", comment: "")
        case .mergeSameDanmaku:
            return NSLocalizedString("合并重复弹幕", comment: "")
        }
    }
}



/// 弹幕展示区域
enum DanmakuAreaType: Int, CaseIterable {
    /// 1/4屏
    case area_1_4
    /// 1/2屏
    case area_1_2
    /// 2/3屏
    case area_2_3
    /// 满屏
    case area_1_1
    
    var value: Double {
        switch self {
        case .area_1_4:
            return 1/4
        case .area_1_2:
            return 1/2
        case .area_2_3:
            return 2/3
        case .area_1_1:
            return 1
        }
    }
    
    var title: String {
        switch self {
        case .area_1_4:
            return NSLocalizedString("1/4屏", comment: "")
        case .area_1_2:
            return NSLocalizedString("1/2屏", comment: "")
        case .area_2_3:
            return NSLocalizedString("2/3屏", comment: "")
        case .area_1_1:
            return NSLocalizedString("满屏", comment: "")
        }
    }
}

/// 全局设置
enum GlobalSettingType: CaseIterable {
    case fastMatch
    case autoLoadCustomDanmaku
    case autoLoadCustomSubtitle
    case danmakuCacheDay
    case subtitleLoadOrder
    case host
    case log
    case cleanupCache
    case cleanupHistory
    
    var title: String {
        switch self {
        case .fastMatch:
            return NSLocalizedString("快速匹配弹幕", comment: "")
        case .danmakuCacheDay:
            return NSLocalizedString("弹幕缓存时间", comment: "")
        case .autoLoadCustomDanmaku:
            return NSLocalizedString("自动加载本地弹幕", comment: "")
        case .subtitleLoadOrder:
            return NSLocalizedString("字幕加载顺序", comment: "")
        case .host:
            return NSLocalizedString("请求域名", comment: "")
        case .log:
            return NSLocalizedString("日志", comment: "")
        case .cleanupCache:
            return NSLocalizedString("清除缓存", comment: "")
        case .autoLoadCustomSubtitle:
            return NSLocalizedString("自动加载本地字幕", comment: "")
        case .cleanupHistory:
            return NSLocalizedString("清除播放记录", comment: "")
        }
    }
}

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

//默认请求域名
let DefaultHost = "https://api.dandanplay.net"
