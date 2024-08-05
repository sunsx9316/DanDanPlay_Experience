//
//  PlayerDanmakuContext.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/4.
//

import Foundation
import RxSwift

class PlayerDanmakuContext {
    
    lazy var danmakuAlpha = BehaviorSubject<Float>(value: Float(Preferences.shared.danmakuAlpha))
    
    lazy var danmakuSpeed = BehaviorSubject<Double>(value: Preferences.shared.danmakuSpeed)
    
    lazy var danmakuFont = BehaviorSubject<ANXFont>(value: ANXFont.systemFont(ofSize: CGFloat(Preferences.shared.danmakuFontSize)))
    
    /// 弹幕和屏幕的占比
    lazy var danmakuArea = BehaviorSubject<DanmakuAreaType>(value: Preferences.shared.danmakuArea)
    
    lazy var isShowDanmaku = BehaviorSubject<Bool>(value: Preferences.shared.isShowDanmaku)
    
    lazy var danmakuOffsetTime = BehaviorSubject<Int>(value: Preferences.shared.danmakuOffsetTime)
    
    /// 弹幕密度
    lazy var danmakuDensity = BehaviorSubject<Float>(value: Preferences.shared.danmakuDensity)
    
    /// 合并相同弹幕
    lazy var isMergeSameDanmaku = BehaviorSubject<Bool>(value: Preferences.shared.isMergeSameDanmaku)
}
