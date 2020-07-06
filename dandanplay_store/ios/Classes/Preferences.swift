//
//  Preferences.swift
//  Runner
//
//  Created by JimHuang on 2020/3/12.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation

open class Preferences {
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
    }
    
    public enum PlayerMode: Int {
      case notRepeat
      case repeatCurrentItem
      case repeatAllItem
    }
    
    public static let shared = Preferences()
    private init() {}
    
    open var checkUpdate: Bool {
        get {
            return Store.shared.value(forKey: KeyName.checkUpdate.rawValue)
        }
        
        set {
            _ = Store.shared.set(newValue, forKey: KeyName.checkUpdate.rawValue)
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
    
    open var playerSpeed: Double {
        get {
            return Store.shared.value(forKey: KeyName.playerSpeed.rawValue)
        }
        
        set {
            _ = Store.shared.set(newValue, forKey: KeyName.playerSpeed.rawValue)
        }
    }
    
    open var showHomePageTips: Bool {
        get {
            return Store.shared.value(forKey: KeyName.showHomePageTips.rawValue)
        }
        
        set {
            _ = Store.shared.set(newValue, forKey: KeyName.showHomePageTips.rawValue)
        }
    }

    
    open var danmakuUnlimitCount: Int {
        return 100
    }
    
    open var danmakuCount: Int {
        get {
            return Store.shared.value(forKey: KeyName.danmakuCount.rawValue)
        }
        
        set {
            _ = Store.shared.set(newValue, forKey: KeyName.danmakuCount.rawValue)
        }
    }
    
    open var danmakuAlpha: Double {
        get {
            return Store.shared.value(forKey: KeyName.danmakuAlpha.rawValue)
        }
        
        set {
            _ = Store.shared.set(newValue, forKey: KeyName.danmakuAlpha.rawValue)
        }
    }
    
    open var fastMatch: Bool {
        get {
            return Store.shared.value(forKey: KeyName.fastMatch.rawValue)
        }
        
        set {
            _ = Store.shared.set(newValue, forKey: KeyName.fastMatch.rawValue)
        }
    }
    
    open var subtitleSafeArea: Bool {
        get {
            return Store.shared.value(forKey: KeyName.subtitleSafeArea.rawValue)
        }
        
        set {
            _ = Store.shared.set(newValue, forKey: KeyName.subtitleSafeArea.rawValue)
        }
    }
    
    open var danmakuCacheDay: Int {
        get {
            return Store.shared.value(forKey: KeyName.danmakuCacheDay.rawValue)
        }
        
        set {
            _ = Store.shared.set(newValue, forKey: KeyName.danmakuCacheDay.rawValue)
        }
    }
    
    open var danmakuFontSize: Double {
        get {
            return Store.shared.value(forKey: KeyName.danmakuFontSize.rawValue)
        }
        
        set {
            _ = Store.shared.set(newValue, forKey: KeyName.danmakuFontSize.rawValue)
        }
    }
    
    open var danmakuSpeed: Double {
        get {
            return Store.shared.value(forKey: KeyName.danmakuSpeed.rawValue)
        }
        
        set {
            _ = Store.shared.set(Double(newValue), forKey: KeyName.danmakuSpeed.rawValue)
        }
    }
    
}
