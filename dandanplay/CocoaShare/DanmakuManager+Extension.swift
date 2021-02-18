//
//  DanmakuManager+Extension.swift
//  Runner
//
//  Created by jimhuang on 2021/2/17.
//  Copyright © 2021 The Flutter Authors. All rights reserved.
//

import DDPShare
#if os(iOS)
import YYCategories
#else
import DDPCategory
#endif
import JHDanmakuRender

enum DanmakuError: LocalizedError {
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .parseError:
            return "弹幕解析错误"
        }
    }
}

extension DanmakuManager {
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
