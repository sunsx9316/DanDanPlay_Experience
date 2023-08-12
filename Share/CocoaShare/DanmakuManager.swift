//
//  DanmakuManager.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/4.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import Foundation
import DanmakuRender
#if os(iOS)
import YYCategories
#else
import DDPCategory
#endif

typealias DanmakuEntity = (BaseDanmaku & RepeatDanmakuInfoProtocol)
typealias DanmakuConverResult = () -> DanmakuEntity

class RepeatDanmakuInfo {
    
    weak var danmaku: BaseDanmaku?
    
    /// 原始文案
    let originText: NSString
    
    /// 重复次数
    var repeatCount = 0 {
        didSet {
            if self.repeatCount > 0 {
                self.danmaku?.text = (self.originText as String) + ": \(self.repeatCount)"
            }
        }
    }
    
    init(danmaku: BaseDanmaku) {
        self.danmaku = danmaku
        self.originText = danmaku.text as NSString
    }
    
}

protocol RepeatDanmakuInfoProtocol: AnyObject {
    
    var repeatDanmakuInfo: RepeatDanmakuInfo? { set get }
    
}

private class _ScrollDanmaku: ScrollDanmaku, RepeatDanmakuInfoProtocol {
    
    var repeatDanmakuInfo: RepeatDanmakuInfo?
    
    override func willMoveOutCanvas(_ context: DanmakuContext) {
        super.willMoveOutCanvas(context)
        self.repeatDanmakuInfo = nil
    }
    
}
 

private class _FloatDanmaku: FloatDanmaku, RepeatDanmakuInfoProtocol {
    
    var repeatDanmakuInfo: RepeatDanmakuInfo?
    
    override func willMoveOutCanvas(_ context: DanmakuContext) {
        super.willMoveOutCanvas(context)
        
        self.repeatDanmakuInfo = nil
    }
    
}

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
    
    /// 加载本地弹幕
    /// - Parameters:
    ///   - file: 弹幕文件
    ///   - completion: 完成回调
    func downCustomDanmaku(_ file: File, completion: @escaping((Result<URL, Error>) -> Void)) {
        var cacheURL = PathUtils.cacheURL
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
        type(of: media).fileManager.danmakusOfMedia(media) { result in
            switch result {
            case .success(let files):
                completion(.success(files))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func conver(_ danmakus: [Comment]) -> [UInt : [DanmakuConverResult]] {
        var dic = [UInt : [DanmakuConverResult]]()
        for model in danmakus {
            if model.time < 0 {
                continue
            }
            let intTime = UInt(model.time)
            if dic[intTime] == nil {
                dic[intTime] = [DanmakuConverResult]()
            }
            
            dic[intTime]?.append({
                return self.conver(model)
            })
        }
        
        return dic
    }
    
    func conver(_ danmakuURL: URL) throws -> [UInt : [DanmakuConverResult]] {
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
                                model.color = ANXColor(rgb: Int(strArr[3]) ?? 0)
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
    
    /// 将弹幕数据转为可播放的弹幕模型
    /// - Parameter model: 弹幕数据
    /// - Returns: 弹幕模型
    private func conver(_ model: Comment) -> DanmakuEntity {
        let fontSize = CGFloat(Preferences.shared.danmakuFontSize)
        
        switch model.mode {
        case .normal:
            let danmakuSpeed = Preferences.shared.danmakuSpeed
            let aDanmaku = _ScrollDanmaku(text: model.message, textColor: model.color, font: .systemFont(ofSize: fontSize), effectStyle: .stroke, direction: .toLeft)
            aDanmaku.appearTime = model.time
            aDanmaku.extraSpeed = danmakuSpeed
            return aDanmaku
        case .bottom, .top:
            let position: FloatDanmaku.Position = model.mode == .bottom ? .atBottom : .atTop
            let aDanmaku = _FloatDanmaku(text: model.message, textColor: model.color, font: .systemFont(ofSize: fontSize), effectStyle: .stroke, position: position, lifeTime: 3)
            aDanmaku.appearTime = model.time
            return aDanmaku
        }
    }
}
