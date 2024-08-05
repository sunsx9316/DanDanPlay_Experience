//
//  PlayerMediaContext.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/4.
//

import Foundation
import RxSwift

class PlayerMediaContext {
    
    /// 时间信息
    struct TimeInfo {
        let currentTime: TimeInterval
        let totalTime: TimeInterval
    }
    
    lazy var isPlay = BehaviorSubject<Bool>(value: false)
    
    lazy var time = BehaviorSubject<TimeInfo>(value: TimeInfo(currentTime: 0, totalTime: 0))
    
    lazy var buffer = BehaviorSubject<[MediaBufferInfo]?>(value: nil)
    
    lazy var media = BehaviorSubject<File?>(value: nil)
    
    lazy var playList = BehaviorSubject<[File]?>(value: nil)
    
    
    lazy var subtitleSafeArea = BehaviorSubject<Bool>(value: Preferences.shared.subtitleSafeArea)
    
    lazy var playerSpeed = BehaviorSubject<Double>(value: Preferences.shared.playerSpeed)
    
    lazy var playerMode = BehaviorSubject<PlayerMode>(value: Preferences.shared.playerMode)
    
    lazy var subtitleOffsetTime = BehaviorSubject<Int>(value: Preferences.shared.subtitleOffsetTime)
    
    lazy var subtitleMargin = BehaviorSubject<Int>(value: Preferences.shared.subtitleMargin)
    
    lazy var subtitleFontSize = BehaviorSubject<Float>(value: Preferences.shared.subtitleFontSize)
    
    lazy var autoJumpTitleEnding = BehaviorSubject<Bool>(value: Preferences.shared.autoJumpTitleEnding)
    
    lazy var jumpTitleDuration = BehaviorSubject<Double>(value: Preferences.shared.jumpTitleDuration)
    
    lazy var jumpEndingDuration = BehaviorSubject<Double>(value: Preferences.shared.jumpEndingDuration)
    
    lazy var volume = PublishSubject<Int>()
    
    /// 播放文件事件
    lazy var playMediaEvent = PublishSubject<File>()
}
