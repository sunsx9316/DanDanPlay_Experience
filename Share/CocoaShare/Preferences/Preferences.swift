//
//  Preferences.swift
//  Runner
//
//  Created by JimHuang on 2020/3/12.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import DanmakuRender
#endif

class Preferences {
    
    /// 偏好设置
    enum KeyName: String {
        /// 是否开启快速匹配
        case fastMatch
        /// 防挡字幕
        case subtitleSafeArea
        /// 弹幕缓存时间
        case danmakuCacheDay
        /// 弹幕字体大小
        case danmakuFontSize
        /// 弹幕速度
        case danmakuSpeed
        /// 弹幕透明度
        case danmakuAlpha
        
        /// 弹幕在屏幕中的展示区域
        case danmakuArea
        
        /// 展示首页提示
        case showHomePageTips
        
        /// 播放速度
        case playerSpeed
        
        /// 播放模式 单曲循环等
        case playerMode
        
        /// 是否检查更新
        case checkUpdate
        
        /// 发送的弹幕类型
        case sendDanmakuType
        
        /// 发送的弹幕颜色
        case sendDanmakuColor

        /// 发送弹幕颜色列表
        case sendDanmakuColors
        
        /// 弹幕开关
        case showDanmaku
        
        /// 是否自动加载本地弹幕
        case autoLoadCustomDanmaku
        
        /// 是否自动加载本地字幕
        case autoLoadCustomSubtitle
        
        /// 弹幕偏移时间
        case danmakuOffsetTime
        
        /// 弹幕偏移时间
        case subtitleOffsetTime
        
        /// smb登录信息
        case smbLoginInfo
        
        /// webdav登录信息
        case webDavLoginInfo
        
        /// ftp登录信息
        case ftpLoginInfo
        
        /// 电脑端登录信息
        case pcLoginInfo
        
        /// 字幕加载顺序关键字
        case subtitleLoadOrder
        
        /// 弹幕密度
        case danmakuDensity = "danmakuDensity_v2"
        
        /// 域名
        case host
        
        /// 上次更新的版本号
        case lastUpdateVersion
        
        /// 合并重复弹幕
        case mergeSameDanmaku
        
        /// 自动跳过片头片尾
        case autoJumpTitleEnding
        
        /// 自动跳过片头时长
        case jumpTitleDuration
        
        /// 自动跳过片尾时长
        case jumpEndingDuration
        
        /// 登录信息
        case loginInfo
        
        /// 字幕Y位置百分比
        case subtitleYPosition
        
        /// 字幕字体大小
        case subtitleFontSize
        
        /// 字幕字体名
        case subtitleFontName
        
        /// 音频偏移
        case audioOffsetTime
        
        /// 屏蔽弹幕
        case filterDanmaku
        
        /// 边缘样式
        case danmakuEffectStyle
        
        /// 主题色
        case mainColor = "mainColor_v2"
        
        /// 弹幕随机颜色
        case openDanmakuRandomColor
        
        /// 长宽比
        case aspectRatio

        /// 播放器内核
        case playerCore

        /// 应用语言 0=系统默认 1=中文 2=英文
        case appLanguage

        /// 字幕颜色
        case subtitleColor

        /// 字幕样式开关
        case subtitleStyle

        /// 自定义域名列表
        case customHosts

        /// 备用域名缓存
        case backupHosts

        var storeKey: String {
            return self.rawValue
        }
    }
    
    static let shared = Preferences()
    private init() {}
    
    @StoreWrapper(defaultValue: PlayerAspectRatio.default, key: .aspectRatio)
    var aspectRatio: PlayerAspectRatio

    @StoreWrapper(defaultValueGetter: {
#if os(iOS) || os(tvOS)
        if #available(iOS 14, tvOS 14, *) {
            return .mpv
        } else {
            return .vlc
        }
#else
        return .vlc
#endif
    }, key: .playerCore)
    var playerCore: MediaPlayer.CoreType

    /// 应用语言
    @StoreWrapper(defaultValue: .chinese, key: .appLanguage)
    var appLanguage: AppLanguage

    /// 字幕颜色（nil 表示使用默认颜色）
    var subtitleColor: ANXColor? {
        get {
            let key = KeyName.subtitleColor
            return Store.shared.value(forKey: key.storeKey)
        }
        set {
            let key = KeyName.subtitleColor
            if let newValue = newValue {
                Store.shared.set(newValue, forKey: key.storeKey)
            } else {
                Store.shared.remove(key.storeKey)
            }
        }
    }

    /// 字幕样式开关
    @StoreWrapper(defaultValue: true, key: .subtitleStyle)
    var subtitleStyle: Bool

    @StoreWrapper(defaultValue: ANXColor.defaultMainColor, key: .mainColor)
    var mainColor: ANXColor
    
    @StoreWrapper(defaultValue: "0", key: .lastUpdateVersion)
    var lastUpdateVersion: String
    
    @StoreWrapper(defaultValue: 0, key: .danmakuOffsetTime)
    var danmakuOffsetTime: Int
    
    @StoreWrapper(defaultValue: 0, key: .subtitleOffsetTime)
    var subtitleOffsetTime: Int
    
    @StoreWrapper(defaultValue: 0, key: .audioOffsetTime)
    var audioOffsetTime: Int
    
    @StoreWrapper(defaultValue: true, key: .autoLoadCustomDanmaku)
    var autoLoadCustomDanmaku: Bool
    
    @StoreWrapper(defaultValue: true, key: .autoLoadCustomSubtitle)
    var autoLoadCustomSubtitle: Bool
    
    @StoreWrapper(defaultValue: true, key: .showDanmaku)
    var isShowDanmaku: Bool
    
    @StoreWrapper(defaultValue: true, key: .checkUpdate)
    var checkUpdate: Bool
    
    @StoreWrapper(defaultValue: DefaultHost, key: .host)
    var host: String
    
    @StoreWrapper(defaultValue: true, key: .mergeSameDanmaku)
    var isMergeSameDanmaku: Bool
    
    @StoreWrapper(defaultValue: false, key: .autoJumpTitleEnding)
    var autoJumpTitleEnding: Bool
    
    @StoreWrapper(defaultValue: 0.0, key: .jumpTitleDuration)
    var jumpTitleDuration: Double
    
    @StoreWrapper(defaultValue: 0.0, key: .jumpEndingDuration)
    var jumpEndingDuration: Double
    
    @StoreWrapper(defaultValue: 0, key: .subtitleYPosition)
    var subtitleYPosition: Float
    
    @StoreWrapper(defaultValue: {
        #if os(tvOS)
        return 35
        #else
        return 20
        #endif
    }(), key: .subtitleFontSize)
    var subtitleFontSize: Float
    
    @StoreWrapper(defaultValue: "", key: .subtitleFontName)
    var subtitleFontName: String
    
    @StoreWrapper(defaultValue: false, key: .openDanmakuRandomColor)
    var openDanmakuRandomColor: Bool
    
    @StoreWrapper(defaultValue: nil, key: .loginInfo)
    var loginInfo: AnixLoginInfo? {
        didSet {
            NotificationCenter.default.post(name: .AnixUserLoginStateDidChange, object: nil)
        }
    }
    
    
    @StoreWrapper(defaultValue: Comment.Mode.normal, key: .sendDanmakuType)
    var sendDanmakuType: Comment.Mode
    
    @StoreWrapper(defaultValue: ANXColor.white, key: .sendDanmakuColor)
    var sendDanmakuColor: ANXColor

    static let defaultSendDanmakuColors: [ANXColor] = [
        ANXColor(anxRgb: 0xFFFFFF),
        ANXColor(anxRgb: 0xFF0000),
        ANXColor(anxRgb: 0x00FF00),
        ANXColor(anxRgb: 0x0000FF),
        ANXColor(anxRgb: 0xFFFF00),
        ANXColor(anxRgb: 0xFF00FF),
    ]

    var sendDanmakuColors: [ANXColor] {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.sendDanmakuColors.storeKey) {
                do {
                    let hexValues = try JSONDecoder().decode([UInt].self, from: jsonData)
                    return hexValues.compactMap { ANXColor.create(from: $0) }
                } catch {
                    debugPrint("读取 sendDanmakuColors 失败 error: \(error)")
                }
            }
            return Self.defaultSendDanmakuColors
        }
        set {
            do {
                let hexValues = newValue.map { $0.toValue() }
                let data = try JSONEncoder().encode(hexValues)
                Store.shared.set(data, forKey: KeyName.sendDanmakuColors.storeKey)
            } catch {
                debugPrint("设置 sendDanmakuColors 失败 error: \(error)")
            }
        }
    }
    
    @StoreWrapper(defaultValue: PlayerMode.autoPlayNext, key: .playerMode)
    var playerMode: PlayerMode
    
    @StoreWrapper(defaultValue: 1, key: .playerSpeed)
    var playerSpeed: Double
    
    @StoreWrapper(defaultValue: true, key: .showHomePageTips)
    var showHomePageTips: Bool
    
    @StoreWrapper(defaultValue: DanmakuAreaType.area_1_1, key: .danmakuArea)
    var danmakuArea: DanmakuAreaType
    
    @StoreWrapper(defaultValue: 1, key: .danmakuAlpha)
    var danmakuAlpha: Double
    
    @StoreWrapper(defaultValue: true, key: .fastMatch)
    var fastMatch: Bool
    
    @StoreWrapper(defaultValue: true, key: .subtitleSafeArea)
    var subtitleSafeArea: Bool
    
    @StoreWrapper(defaultValue: 7, key: .danmakuCacheDay)
    var danmakuCacheDay: Int
    
    #if os(tvOS)
    @StoreWrapper(defaultValue: 30, key: .danmakuFontSize)
    #else
    @StoreWrapper(defaultValue: 20, key: .danmakuFontSize)
    #endif
    var danmakuFontSize: Double
    
    @StoreWrapper(defaultValue: 1, key: .danmakuSpeed)
    var danmakuSpeed: Double
    
    /// 弹幕密度 取值 1 ~ 10
    @StoreWrapper(defaultValue: 10, key: .danmakuDensity)
    var danmakuDensity: Float
    
#if os(iOS) || os(tvOS)
    /// 弹幕边缘样式
    @StoreWrapper(defaultValue: DanmakuEffectStyle.stroke, key: .danmakuEffectStyle)
    var danmakuEffectStyle: DanmakuEffectStyle
#endif
    
    var pcLoginInfos: [LoginInfo]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.pcLoginInfo.storeKey) {
                do {
                    let loginInfo = try JSONDecoder().decode([LoginInfo].self, from: jsonData)
                    return loginInfo
                } catch let error {
                    debugPrint("读取 pcLoginInfos 失败 error: \(error)")
                }
            }
            return nil
        }
        
        set {
            if let newValue = newValue {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    Store.shared.set(data, forKey: KeyName.pcLoginInfo.storeKey)
                } catch let error {
                    debugPrint("设置 pcLoginInfos 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.pcLoginInfo.storeKey)
            }
        }
    }
    
    var smbLoginInfos: [LoginInfo]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.smbLoginInfo.storeKey) {
                do {
                    let smbLoginInfo = try JSONDecoder().decode([LoginInfo].self, from: jsonData)
                    return smbLoginInfo
                } catch let error {
                    debugPrint("读取 smbLoginInfo 失败 error: \(error)")
                }
            }
            return nil
        }
        
        set {
            if let newValue = newValue {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    Store.shared.set(data, forKey: KeyName.smbLoginInfo.storeKey)
                } catch let error {
                    debugPrint("设置 smbLoginInfo 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.smbLoginInfo.storeKey)
            }
        }
    }
    
    var webDavLoginInfos: [LoginInfo]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.webDavLoginInfo.storeKey) {
                do {
                    let loginInfo = try JSONDecoder().decode([LoginInfo].self, from: jsonData)
                    return loginInfo
                } catch let error {
                    debugPrint("读取 webDavLoginInfos 失败 error: \(error)")
                }
            }
            return nil
        }
        
        set {
            if let newValue = newValue {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    Store.shared.set(data, forKey: KeyName.webDavLoginInfo.storeKey)
                } catch let error {
                    debugPrint("设置 webDavLoginInfos 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.webDavLoginInfo.storeKey)
            }
        }
    }
    
    var ftpLoginInfos: [LoginInfo]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.ftpLoginInfo.storeKey) {
                do {
                    let loginInfo = try JSONDecoder().decode([LoginInfo].self, from: jsonData)
                    return loginInfo
                } catch let error {
                    debugPrint("读取 ftpLoginInfos 失败 error: \(error)")
                }
            }
            return nil
        }
        
        set {
            if let newValue = newValue {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    Store.shared.set(data, forKey: KeyName.ftpLoginInfo.storeKey)
                } catch let error {
                    debugPrint("设置 webDavLoginInfos 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.ftpLoginInfo.storeKey)
            }
        }
    }
    
    var subtitleLoadOrder: [String]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.subtitleLoadOrder.storeKey) {
                do {
                    let loadOrder = try JSONDecoder().decode([String].self, from: jsonData)
                    return loadOrder
                } catch let error {
                    debugPrint("读取 subtitleLoadOrder 失败 error: \(error)")
                }
            }
            return nil
        }
        
        set {
            if let newValue = newValue {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    Store.shared.set(data, forKey: KeyName.subtitleLoadOrder.storeKey)
                } catch let error {
                    debugPrint("设置 subtitleLoadOrder 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.subtitleLoadOrder.storeKey)
            }
        }
    }
    
    var filterDanmakus: [FilterDanmaku]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.filterDanmaku.storeKey) {
                do {
                    let shildDanmaku = try JSONDecoder().decode([FilterDanmaku].self, from: jsonData)
                    return shildDanmaku
                } catch let error {
                    debugPrint("读取 filterDanmaku 失败 error: \(error)")
                }
            }
            return nil
        }

        set {
            if let newValue = newValue {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    Store.shared.set(data, forKey: KeyName.filterDanmaku.storeKey)
                } catch let error {
                    debugPrint("设置 filterDanmaku 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.filterDanmaku.storeKey)
            }
        }
    }

    /// 自定义域名列表
    var customHosts: [String]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.customHosts.storeKey) {
                do {
                    let hosts = try JSONDecoder().decode([String].self, from: jsonData)
                    return hosts
                } catch let error {
                    debugPrint("读取 customHosts 失败 error: \(error)")
                }
            }
            return nil
        }

        set {
            if let newValue = newValue {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    Store.shared.set(data, forKey: KeyName.customHosts.storeKey)
                } catch let error {
                    debugPrint("设置 customHosts 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.customHosts.storeKey)
            }
        }
    }

    /// 备用域名缓存
    var backupHosts: [String]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.backupHosts.storeKey) {
                do {
                    let hosts = try JSONDecoder().decode([String].self, from: jsonData)
                    return hosts
                } catch let error {
                    debugPrint("读取 backupHosts 失败 error: \(error)")
                }
            }
            return nil
        }

        set {
            if let newValue = newValue {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    Store.shared.set(data, forKey: KeyName.backupHosts.storeKey)
                } catch let error {
                    debugPrint("设置 backupHosts 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.backupHosts.storeKey)
            }
        }
    }

}

extension Preferences {
    @propertyWrapper
    struct StoreWrapper<Value: Storeable> {
        
        private var value: Value
        private var key: KeyName
        
        init(defaultValue: Value, key: KeyName) {
            self.value = defaultValue
            self.key = key
        }
        
        init(defaultValueGetter: () -> Value, key: KeyName) {
            self.value = defaultValueGetter()
            self.key = key
        }

        var wrappedValue: Value {
            get {
                return Store.shared.value(forKey: key.storeKey) ?? self.value
            }
            set {
                Store.shared.set(newValue, forKey: key.storeKey)
            }
        }
    }
}
