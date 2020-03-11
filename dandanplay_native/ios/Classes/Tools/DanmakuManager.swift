//
//  DanmakuManager.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/4.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import Foundation
import JHDanmakuRender

class DanmakuManager {
    static let shared = DanmakuManager()
    
    func conver(_ danmakus: [DanmakuModel]) -> [UInt : [JHDanmakuProtocol]] {
        var dic = [UInt : [JHDanmakuProtocol]]()
        for model in danmakus {
            let intTime = UInt(model.time)
            if dic[intTime] == nil {
                dic[intTime] = [JHDanmakuProtocol]()
            }
            
            switch model.mode {
            case .normal:
                let aDanmaku = JHScrollDanmaku(font: nil, text: model.message, textColor: model.color, effectStyle: .glow, direction: .R2L)
                aDanmaku.appearTime = model.time
                dic[intTime]?.append(aDanmaku)
            case .bottom, .top:
                let position: JHFloatDanmakuPosition = model.mode == .bottom ? .atBottom : .atTop
                let aDanmaku = JHFloatDanmaku(font: nil, text: model.message, textColor: model.color, effectStyle: .glow, during: 0, position: position)
                aDanmaku.appearTime = model.time
                dic[intTime]?.append(aDanmaku)
            }
        }
        
        return dic
    }
}
