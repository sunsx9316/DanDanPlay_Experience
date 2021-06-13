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

private enum DanmakuError: LocalizedError {
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .parseError:
            return "弹幕解析错误"
        }
    }
}

class DanmakuManager {
    
    static let shared = DanmakuManager()
    
    private init() {}
    
    /// 下载本地弹幕
    /// - Parameters:
    ///   - file: 弹幕文件
    ///   - completion: 完成回调
    func downCustomDanmaku(_ file: File, completion: @escaping((Result<URL, Error>) -> Void)) {
        var cacheURL = UIApplication.shared.cachesURL
        cacheURL.appendPathComponent(file.fileHash)
        
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            file.getDataWithProgress(nil) { result in
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: cacheURL, options: .atomic)
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
    }
    
    
    /// 根据视频查找本地弹幕
    /// - Parameters:
    ///   - media: 视频
    ///   - completion: 完成回调
    func findCustomDanmakuWithMedia(_ media: File, completion: @escaping((Result<[File], Error>) -> Void)) {
        if let parentFile = media.parentFile {
            let name = media.url.deletingPathExtension().lastPathComponent
            media.fileManager.danmakusOfDirectory(at: parentFile) { result in
                switch result {
                case .success(let files):
                    let danmakuFiles = files.filter({ $0.url.lastPathComponent.contains(name) })
                    completion(.success(danmakuFiles))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.success([]))
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
