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
    case customDanmakuNotExit
    
    var errorDescription: String? {
        switch self {
        case .parseError:
            return "弹幕解析错误"
        case .customDanmakuNotExit:
            return "本地弹幕不存在"
        }
    }
}

class DanmakuManager {
    static let shared = DanmakuManager()
    
    private init() {}
    
    func loadCustomDanmakuWithMedia(_ media: File, completion: @escaping((Result<URL, Error>) -> Void)) {
        //加载本地弹幕
        if let parentFile = media.parentFile {
            let name = media.url.deletingPathExtension().lastPathComponent
            media.fileManager.danmakusOfDirectory(at: parentFile) { result in
                switch result {
                case .success(let files):
                    if let file = files.first(where: { $0.url.lastPathComponent.contains(name) }) {
                        
                        var cacheURL = UIApplication.shared.cachesURL
                        cacheURL.appendPathComponent(file.fileHash)
                        
                        if !FileManager.default.fileExists(atPath: cacheURL.path) {
                            file.getDataWithProgress(nil) { result in
                                switch result {
                                case .success(let data):
                                    do {
                                        try data.write(to: cacheURL)
                                        completion(.success(cacheURL))
                                    } catch (let error) {
                                        completion(.failure(error))
                                    }
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            completion(.success(cacheURL))
                        }
                    } else {
                        completion(.failure(DanmakuError.customDanmakuNotExit))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.failure(DanmakuError.customDanmakuNotExit))
        }
    }
    
    func conver(_ danmakus: [Comment]) -> [UInt : [JHDanmakuProtocol]] {
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
    
    func conver(_ model: Comment) -> JHDanmakuProtocol {
        
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
                    var danmakuModels = [Comment]()
                    for d in arr {
                        if let p = d["p"] as? String {
                            let strArr = p.components(separatedBy: ",")
                            if strArr.count >= 4, let text = d["_text"] as? String {
                                var model = Comment()
                                model.time = TimeInterval(strArr[0]) ?? 0
                                model.mode = Comment.Mode(rawValue: Int(strArr[1]) ?? 1) ?? .normal
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
