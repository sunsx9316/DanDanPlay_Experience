//
//  Preferences.swift
//  Runner
//
//  Created by JimHuang on 2020/3/12.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation
import DanmakuRender

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
        
        /// 字幕偏移
        case subtitleMargin
        
        /// 字幕字体大小
        case subtitleFontSize
        
        /// 音频偏移
        case audioOffsetTime
        
        /// 屏蔽弹幕
        case filterDanmaku
        
        /// 边缘样式
        case danmakuEffectStyle
        
        var storeKey: String {
            return self.rawValue
        }
    }
    
    static let shared = Preferences()
    private init() {}
    
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
    
    @StoreWrapper(defaultValue: 0, key: .subtitleMargin)
    var subtitleMargin: Int
    
    @StoreWrapper(defaultValue: 20, key: .subtitleFontSize)
    var subtitleFontSize: Float
    
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
    
    @StoreWrapper(defaultValue: 20, key: .danmakuFontSize)
    var danmakuFontSize: Double
    
    @StoreWrapper(defaultValue: 1, key: .danmakuSpeed)
    var danmakuSpeed: Double
    
    /// 弹幕密度 取值 1 ~ 10
    @StoreWrapper(defaultValue: 10, key: .danmakuDensity)
    var danmakuDensity: Float
    
    /// 弹幕边缘样式
    @StoreWrapper(defaultValue: DanmakuEffectStyle.stroke, key: .danmakuEffectStyle)
    var danmakuEffectStyle: DanmakuEffectStyle
    
    var pcLoginInfos: [LoginInfo]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.pcLoginInfo.rawValue) {
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
                    Store.shared.set(data, forKey: KeyName.pcLoginInfo.rawValue)
                } catch let error {
                    debugPrint("设置 pcLoginInfos 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.pcLoginInfo.rawValue)
            }
        }
    }
    
    var smbLoginInfos: [LoginInfo]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.smbLoginInfo.rawValue) {
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
                    Store.shared.set(data, forKey: KeyName.smbLoginInfo.rawValue)
                } catch let error {
                    debugPrint("设置 smbLoginInfo 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.smbLoginInfo.rawValue)
            }
        }
    }
    
    var webDavLoginInfos: [LoginInfo]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.webDavLoginInfo.rawValue) {
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
                    Store.shared.set(data, forKey: KeyName.webDavLoginInfo.rawValue)
                } catch let error {
                    debugPrint("设置 webDavLoginInfos 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.webDavLoginInfo.rawValue)
            }
        }
    }
    
    var ftpLoginInfos: [LoginInfo]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.ftpLoginInfo.rawValue) {
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
                    Store.shared.set(data, forKey: KeyName.ftpLoginInfo.rawValue)
                } catch let error {
                    debugPrint("设置 webDavLoginInfos 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.ftpLoginInfo.rawValue)
            }
        }
    }
    
    var subtitleLoadOrder: [String]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.subtitleLoadOrder.rawValue) {
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
                    Store.shared.set(data, forKey: KeyName.subtitleLoadOrder.rawValue)
                } catch let error {
                    debugPrint("设置 subtitleLoadOrder 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.subtitleLoadOrder.rawValue)
            }
        }
    }
    
    var filterDanmakus: [FilterDanmaku]? {
        get {
            if let jsonData: Data = Store.shared.value(forKey: KeyName.filterDanmaku.rawValue) {
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
                    Store.shared.set(data, forKey: KeyName.filterDanmaku.rawValue)
                } catch let error {
                    debugPrint("设置 filterDanmaku 失败 error: \(error)")
                }
            } else {
                Store.shared.remove(KeyName.filterDanmaku.rawValue)
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

        var wrappedValue: Value {
            get {
                return Store.shared.value(forKey: key.storeKey) ?? self.value
            }
            set {
                _ = Store.shared.set(newValue, forKey: key.storeKey)
            }
        }
    }
}
