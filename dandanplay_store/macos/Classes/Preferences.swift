//
//  Preferences.swift
//  Runner
//
//  Created by JimHuang on 2020/3/12.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation
import MMKV

open class Preferences {
    public enum KeyName: String {
        case fastMatch
        case subtitleSafeArea
        case danmakuCacheDay
        case danmakuFontSize
        case danmakuSpeed
        case danmakuAlpha
        case danmakuCount
    }
    
    public static let shared = Preferences()
    private init() {}
    
    open var danmakuUnlimitCount: Int {
        return 100
    }
    
    open var danmakuCount: Int {
           get {
               return Int(MMKV.default().int32(forKey: KeyName.danmakuCount.rawValue))
           }
           
           set {
               MMKV.default().set(Int32(newValue), forKey: KeyName.danmakuCount.rawValue)
           }
       }
    
    open var danmakuAlpha: CGFloat {
        get {
            return CGFloat(MMKV.default().double(forKey: KeyName.danmakuAlpha.rawValue))
        }
        
        set {
            MMKV.default().set(Double(newValue), forKey: KeyName.danmakuAlpha.rawValue)
        }
    }
    
    open var fastMatch: Bool {
        get {
            return MMKV.default().bool(forKey: KeyName.fastMatch.rawValue)
        }
        
        set {
            MMKV.default().set(newValue, forKey: KeyName.fastMatch.rawValue)
        }
    }
    
    open var subtitleSafeArea: Bool {
        get {
            return MMKV.default().bool(forKey: KeyName.subtitleSafeArea.rawValue)
        }
        
        set {
            MMKV.default().set(newValue, forKey: KeyName.subtitleSafeArea.rawValue)
        }
    }
    
    open var danmakuCacheDay: Int32 {
        get {
            return MMKV.default().int32(forKey: KeyName.danmakuCacheDay.rawValue)
        }
        
        set {
            MMKV.default().set(newValue, forKey: KeyName.danmakuCacheDay.rawValue)
        }
    }
    
    open var danmakuFontSize: Double {
        get {
            return MMKV.default().double(forKey: KeyName.danmakuFontSize.rawValue)
        }
        
        set {
            MMKV.default().set(newValue, forKey: KeyName.danmakuFontSize.rawValue)
        }
    }
    
    open var danmakuSpeed: CGFloat {
        get {
            return CGFloat(MMKV.default().double(forKey: KeyName.danmakuSpeed.rawValue))
        }
        
        set {
            MMKV.default().set(Double(newValue), forKey: KeyName.danmakuSpeed.rawValue)
        }
    }
    
    open func setupDefaultValue() {
        if !MMKV.default().contains(key: KeyName.fastMatch.rawValue) {
            fastMatch = true
        }
        
        if !MMKV.default().contains(key: KeyName.subtitleSafeArea.rawValue) {
            subtitleSafeArea = true
        }
        
        if !MMKV.default().contains(key: KeyName.danmakuCacheDay.rawValue) {
            danmakuCacheDay = 7
        }
        
        if !MMKV.default().contains(key: KeyName.danmakuFontSize.rawValue) {
            danmakuFontSize = 20
        }
        
        if !MMKV.default().contains(key: KeyName.danmakuSpeed.rawValue) {
            danmakuSpeed = 1
        }
        
        if !MMKV.default().contains(key: KeyName.danmakuAlpha.rawValue) {
            danmakuAlpha = 1
        }
        
        if !MMKV.default().contains(key: KeyName.danmakuCount.rawValue) {
            danmakuCount = 100
        }
    }
}
