//
//  Preferences.swift
//  Runner
//
//  Created by JimHuang on 2020/3/12.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation

class Preferences {
    
    @propertyWrapper
    struct StoreWrapper<Value> {
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
        
        /// 弹幕在屏幕中的占比
        @available(*, deprecated, message: "已废弃 请不要使用")
        case danmakuStoreProportion
        
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
        
        /// 弹幕偏移时间
        case danmakuOffsetTime
        
        /// smb登录信息
        case smbLoginInfo
        
        /// webdav登录信息
        case webDavLoginInfo
        
        /// ftp登录信息
        case ftpLoginInfo
        
        /// 字幕加载顺序关键字
        case subtitleLoadOrder
        
        /// 弹幕密度
        case danmakuDensity
        
        /// 域名
        case host
        
        /// 上次更新的版本号
        case lastUpdateVersion
        
        var storeKey: String {
            if self == .danmakuDensity {
                return "danmakuDensity_v2"
            }
            return self.rawValue
        }
    }
    
    enum PlayerMode: Int, CaseIterable {
        case notRepeat
        case repeatCurrentItem
        case repeatAllItem
    }
    
    static let shared = Preferences()
    private init() {}
    
    @StoreWrapper(defaultValue: "0", key: .lastUpdateVersion)
    var lastUpdateVersion: String
    
    @StoreWrapper(defaultValue: 0, key: .danmakuOffsetTime)
    var danmakuOffsetTime: Int
    
    @StoreWrapper(defaultValue: true, key: .autoLoadCustomDanmaku)
    var autoLoadCustomDanmaku: Bool
    
    @StoreWrapper(defaultValue: true, key: .showDanmaku)
    var isShowDanmaku: Bool
    
    @StoreWrapper(defaultValue: true, key: .checkUpdate)
    var checkUpdate: Bool
    
    @StoreWrapper(defaultValue: DefaultHost, key: .host)
    var host: String
    
    var sendDanmakuType: DanmakuModel.Mode {
        get {
            let rawValue: Int = Store.shared.value(forKey: KeyName.sendDanmakuType.rawValue) ?? DanmakuModel.Mode.normal.rawValue
            return DanmakuModel.Mode(rawValue: rawValue) ?? .normal
        }
        
        set {
            _ = Store.shared.set(newValue.rawValue, forKey: KeyName.sendDanmakuType.rawValue)
        }
    }
    
    var sendDanmakuColor: ANXColor {
        get {
            let rawValue: Int = Store.shared.value(forKey: KeyName.sendDanmakuColor.rawValue) ?? 0
            return ANXColor(rgba: UInt32(rawValue))
        }
        
        set {
            _ = Store.shared.set(newValue.rgbaValue(), forKey: KeyName.sendDanmakuColor.rawValue)
        }
    }
    
    
    var playerMode: PlayerMode {
        get {
            let rawValue: Int = Store.shared.value(forKey: KeyName.playerMode.rawValue) ?? PlayerMode.notRepeat.rawValue
            return PlayerMode(rawValue: rawValue) ?? .notRepeat
        }
        
        set {
            _ = Store.shared.set(newValue.rawValue, forKey: KeyName.playerMode.rawValue)
        }
    }
    
    var danmakuMaxStoreValue: Int {
        return 100
    }
    
    var danmakuMinStoreValue: Int {
        return 25
    }
    
    var danmakuProportion: Double {
        return Double(self.danmakuStoreProportion) / Double(self.danmakuMaxStoreValue)
    }
    
    @StoreWrapper(defaultValue: 1, key: .playerSpeed)
    var playerSpeed: Double
    
    @StoreWrapper(defaultValue: true, key: .showHomePageTips)
    var showHomePageTips: Bool
    
    @StoreWrapper(defaultValue: 25, key: .danmakuStoreProportion)
    var danmakuStoreProportion: Int /// 弹幕占比 取值 25/50/75，代表1/4 1/2 2/3
    
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
    
    
    @StoreWrapper(defaultValue: 10, key: .danmakuDensity)
    /// 弹幕密度 取值 1 ~ 10
    var danmakuDensity: Float
    
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
    
}
