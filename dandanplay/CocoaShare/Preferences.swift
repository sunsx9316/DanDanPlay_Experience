//
//  Preferences.swift
//  Runner
//
//  Created by JimHuang on 2020/3/12.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation
import DDPShare

open class Preferences {
    
    @propertyWrapper
    public struct StoreWrapper<Value> {
        private var value: Value
        private var key: KeyName
        
        public init(wrappedValue: Value, key: KeyName) {
            self.value = wrappedValue
            self.key = key
        }

        public var wrappedValue: Value {
            get {
                return Store.shared.value(forKey: key.rawValue)
            }
            set {
                _ = Store.shared.set(newValue, forKey: key.rawValue)
            }
        }
    }
    
    public enum KeyName: String {
        case fastMatch
        case subtitleSafeArea
        case danmakuCacheDay
        case danmakuFontSize
        case danmakuSpeed
        case danmakuAlpha
        case danmakuCount
        case showHomePageTips
        case playerSpeed
        case playerMode
        case checkUpdate
        case sendDanmakuType
        case sendDanmakuColor
        case showDanmaku
        case autoLoadCusomDanmaku
        case danmakuOffsetTime
    }
    
    public enum PlayerMode: Int {
      case notRepeat
      case repeatCurrentItem
      case repeatAllItem
    }
    
    public static let shared = Preferences()
    private init() {}
    
    @StoreWrapper(wrappedValue: 0, key: .danmakuOffsetTime)
    open var danmakuOffsetTime: Int
    
    @StoreWrapper(wrappedValue: true, key: .autoLoadCusomDanmaku)
    open var autoLoadCusomDanmaku: Bool
    
    @StoreWrapper(wrappedValue: false, key: .showDanmaku)
    open var showDanmaku: Bool
    
    @StoreWrapper(wrappedValue: true, key: .checkUpdate)
    open var checkUpdate: Bool
    
    open var sendDanmakuType: DanmakuModel.Mode {
        get {
            let rawValue: Int = Store.shared.value(forKey: KeyName.sendDanmakuType.rawValue)
            return DanmakuModel.Mode(rawValue: rawValue) ?? .normal
        }
        
        set {
            _ = Store.shared.set(newValue.rawValue, forKey: KeyName.sendDanmakuType.rawValue)
        }
    }
    
    open var sendDanmakuColor: DDPColor {
        get {
            let rawValue: Int = Store.shared.value(forKey: KeyName.sendDanmakuColor.rawValue)
            return DDPColor(rgba: UInt32(rawValue))
        }
        
        set {
            _ = Store.shared.set(newValue.rgbaValue(), forKey: KeyName.sendDanmakuColor.rawValue)
        }
    }
    
    
    open var playerMode: PlayerMode {
        get {
            let rawValue: Int = Store.shared.value(forKey: KeyName.playerMode.rawValue)
            return PlayerMode(rawValue: rawValue) ?? .notRepeat
        }
        
        set {
            _ = Store.shared.set(newValue.rawValue, forKey: KeyName.playerMode.rawValue)
        }
    }
    
    open var danmakuMode: PlayerMode {
        get {
            let rawValue: Int = Store.shared.value(forKey: KeyName.playerMode.rawValue)
            return PlayerMode(rawValue: rawValue) ?? .notRepeat
        }
        
        set {
            _ = Store.shared.set(newValue.rawValue, forKey: KeyName.playerMode.rawValue)
        }
    }
    
    open var danmakuUnlimitCount: Int {
        return 100
    }
    
    @StoreWrapper(wrappedValue: 1, key: .playerSpeed)
    open var playerSpeed: Double
    
    @StoreWrapper(wrappedValue: true, key: .showHomePageTips)
    open var showHomePageTips: Bool
    
    @StoreWrapper(wrappedValue: 0, key: .danmakuCount)
    open var danmakuCount: Int
    
    @StoreWrapper(wrappedValue: 1, key: .danmakuAlpha)
    open var danmakuAlpha: Double
    
    @StoreWrapper(wrappedValue: true, key: .fastMatch)
    open var fastMatch: Bool
    
    @StoreWrapper(wrappedValue: true, key: .subtitleSafeArea)
    open var subtitleSafeArea: Bool
    
    @StoreWrapper(wrappedValue: 7, key: .danmakuCacheDay)
    open var danmakuCacheDay: Int
    
    @StoreWrapper(wrappedValue: 20, key: .danmakuFontSize)
    open var danmakuFontSize: Double
    
    @StoreWrapper(wrappedValue: 1, key: .danmakuSpeed)
    open var danmakuSpeed: Double
    
}
