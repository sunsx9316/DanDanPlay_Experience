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
                return Store.shared.value(forKey: key.rawValue) ?? self.value
            }
            set {
                _ = Store.shared.set(newValue, forKey: key.rawValue)
            }
        }
    }
    
    enum KeyName: String {
        case fastMatch
        case subtitleSafeArea
        case danmakuCacheDay
        case danmakuFontSize
        case danmakuSpeed
        case danmakuAlpha
        case danmakuStoreProportion
        case showHomePageTips
        case playerSpeed
        case playerMode
        case checkUpdate
        case sendDanmakuType
        case sendDanmakuColor
        case showDanmaku
        case autoLoadCustomDanmaku
        case danmakuOffsetTime
        case smbLoginInfo
        case webDavLoginInfo
        case ftpLoginInfo
        case subtitleLoadOrder
    }
    
    enum PlayerMode: Int, CaseIterable {
        case notRepeat
        case repeatCurrentItem
        case repeatAllItem
    }
    
    static let shared = Preferences()
    private init() {}
    
    @StoreWrapper(defaultValue: 0, key: .danmakuOffsetTime)
    var danmakuOffsetTime: Int
    
    @StoreWrapper(defaultValue: true, key: .autoLoadCustomDanmaku)
    var autoLoadCustomDanmaku: Bool
    
    @StoreWrapper(defaultValue: true, key: .showDanmaku)
    var isShowDanmaku: Bool
    
    @StoreWrapper(defaultValue: true, key: .checkUpdate)
    var checkUpdate: Bool
    
    var sendDanmakuType: DanmakuModel.Mode {
        get {
            let rawValue: Int = Store.shared.value(forKey: KeyName.sendDanmakuType.rawValue) ?? DanmakuModel.Mode.normal.rawValue
            return DanmakuModel.Mode(rawValue: rawValue) ?? .normal
        }
        
        set {
            _ = Store.shared.set(newValue.rawValue, forKey: KeyName.sendDanmakuType.rawValue)
        }
    }
    
    var sendDanmakuColor: DDPColor {
        get {
            let rawValue: Int = Store.shared.value(forKey: KeyName.sendDanmakuColor.rawValue) ?? 0
            return DDPColor(rgba: UInt32(rawValue))
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
