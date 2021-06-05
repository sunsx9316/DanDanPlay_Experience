//
//  DanmakuManager.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/4.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import Foundation
import JHDanmakuRender
#if os(iOS)
import YYCategories
#else
import DDPCategory
#endif

enum DanmakuError: LocalizedError {
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .parseError:
            return "弹幕解析错误"
        }
    }
}

open class DanmakuManager {
    public static let shared = DanmakuManager()
    
    open func conver(_ danmakus: [DanmakuModel]) -> [UInt : [JHDanmakuProtocol]] {
        var dic = [UInt : [JHDanmakuProtocol]]()
        for model in danmakus {
            let intTime = UInt(model.time)
            if dic[intTime] == nil {
                dic[intTime] = [JHDanmakuProtocol]()
            }
            
            dic[intTime]?.append(conver(model))
        }
        
        return dic
    }
    
    open func conver(_ model: DanmakuModel) -> JHDanmakuProtocol {
//        let intTime = UInt(model.time)
        
        switch model.mode {
        case .normal:
            let aDanmaku = JHScrollDanmaku(font: nil, text: model.message, textColor: model.color, effectStyle: .glow, direction: .R2L)
            aDanmaku.appearTime = model.time
            return aDanmaku
        case .bottom, .top:
            let position: JHFloatDanmakuPosition = model.mode == .bottom ? .atBottom : .atTop
            let aDanmaku = JHFloatDanmaku(font: nil, text: model.message, textColor: model.color, effectStyle: .glow, during: 0, position: position)
            aDanmaku.appearTime = model.time
            return aDanmaku
        }
    }
    
    func conver(_ danmakuURL: URL) throws -> [UInt : [JHDanmakuProtocol]] {
        do {
            let data = try Data(contentsOf: danmakuURL)
            if let dic = NSDictionary(xml: data) {
                if let arr = dic["d"] as? [[String : Any]] {
                    var danmakuModels = [DanmakuModel]()
                    for d in arr {
                        if let p = d["p"] as? String {
                            let strArr = p.components(separatedBy: ",")
                            if strArr.count >= 4, let text = d["_text"] as? String {
                                let model = DanmakuModel()
                                model.time = TimeInterval(strArr[0]) ?? 0
                                model.mode = DanmakuModel.Mode(rawValue: Int(strArr[1]) ?? 1) ?? .normal
                                model.color = DDPColor(rgb: Int(strArr[3]) ?? 0)
                                model.message = text
                                danmakuModels.append(model)
                            }
                        }
                    }
                    
                    return self.conver(danmakuModels)
                }
                
                return [:]
            } else {
                throw DanmakuError.parseError
            }
        } catch let error {
            throw error
        }
    }
}
