//
//  DanmakuManager.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/4.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import Foundation
import DanmakuRender
import YYCategories

typealias DanmakuEntity = (BaseDanmaku & DanmakuInfoProtocol)
typealias DanmakuMapResult = [UInt : [DanmakuEntity]]
typealias LoadingProgressAction = ((LoadingState) -> Void)

enum LoadingState {
    case parseMedia
    case downloadLocalDanmaku
    case matchMedia(progress: Double)
    case downloadDanmaku
}

private enum DanmakuLoadError: LocalizedError {
    case notMatch
    case converError
    
    var errorDescription: String? {
        switch self {
        case .notMatch:
            return "没有匹配到本地弹幕"
        case .converError:
            return "弹幕转换失败"
        }
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
    
    /// 加载弹幕
    /// - Parameters:
    ///   - media: 视频
    ///   - progress: 进度
    ///   - matchCompletion: 当匹配多个视频时会进行回调
    ///   - danmakuCompletion: 弹幕加载回调
    func loadDanmaku(_ media: File,
                     progress: LoadingProgressAction?,
                     matchCompletion: @escaping((MatchCollection?, Error?) -> Void),
                     danmakuCompletion: @escaping((DanmakuMapResult?, _ matchInfo: Match?, Error?) -> Void)) {
        progress?(.parseMedia)
        
        if Preferences.shared.autoLoadCustomDanmaku {
            progress?(.downloadLocalDanmaku)
            
            /// 优先进行本地弹幕的加载
            self.loadLocalDanmaku(media) { [weak self] result, error in
                guard let self = self else { return }
                
                let hasLocalDanmaku = result?.isEmpty == false
                if hasLocalDanmaku {
                    /// 尝试进行网络请求，如果失败，则会使用本地弹幕
                    MatchNetworkHandle.matchAndGetDanmakuWithFile(media, progress: progress) { [weak self] matchCollection, error in
                        guard self != nil else { return }
                        
                        /// 进这里说明匹配到多个结果，或关闭了快速匹配
                        danmakuCompletion(result, nil, nil)
                        
                    } getDanmakuCompletion: { [weak self] collection, matchInfo, error in
                        guard let self = self else { return }
                        
                        /// 如果下载到网络弹幕则使用，否则使用本地弹幕
                        if let collection = collection {
                            danmakuCompletion(self.conver(collection.collection), matchInfo, nil)
                        } else {
                            danmakuCompletion(result, nil, nil)
                        }
                    }
                    
                } else {
                    MatchNetworkHandle.matchAndGetDanmakuWithFile(media, progress: progress, matchCompletion: matchCompletion) { collection, episodeId, error in
                        danmakuCompletion(DanmakuManager.shared.conver(collection?.collection ?? []), episodeId, error)
                    }
                }
            }
        } else {
            MatchNetworkHandle.matchAndGetDanmakuWithFile(media, progress: progress, matchCompletion: matchCompletion) { collection, episodeId, error in
                danmakuCompletion(DanmakuManager.shared.conver(collection?.collection ?? []), episodeId, error)
            }
        }
    }
    
    /// 读取弹幕，转换为弹幕map
    /// - Parameter danmakuURL: 弹幕路径
    /// - Returns: 弹幕map
    func conver(_ danmakuURL: URL) throws -> DanmakuMapResult {
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
                                model.color = ANXColor(anxRgb: Int(strArr[3]) ?? 0)
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
    
    /// 将弹幕数组转换为map
    /// - Parameter danmakus: 弹幕数组
    /// - Returns: map
    func conver(_ danmakus: [Comment]) -> DanmakuMapResult {
        var dic = DanmakuMapResult()
        for model in danmakus {
            if model.time < 0 {
                continue
            }
            let intTime = UInt(model.time)
            if dic[intTime] == nil {
                dic[intTime] = [DanmakuEntity]()
            }
            
            dic[intTime]?.append(self.conver(model))
        }
        
        return dic
    }
    
    /// 下载本地弹幕
    /// - Parameters:
    ///   - file: 弹幕文件
    ///   - completion: 完成回调
    func downCustomDanmaku(_ file: File, completion: @escaping((Result<URL, Error>) -> Void)) {
        var cacheURL = PathUtils.cacheURL
        
        let fileURL = cacheURL.appendingPathComponent(file.fileId)
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            file.getDataWithProgress(nil) { result in
                switch result {
                case .success(let data):
                    do {
                        try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
                        try data.write(to: fileURL, options: .atomic)
                        completion(.success(fileURL))
                    } catch (let error) {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.success(fileURL))
        }
    }
    
    // MARK: Private Method
    
    
    /// 加载本地弹幕
    /// - Parameters:
    ///   - media: 视频
    ///   - completion: 完成回调
    private func loadLocalDanmaku(_ media: File, completion: @escaping(DanmakuMapResult?, Error?) -> Void) {
            DanmakuManager.shared.findCustomDanmakuWithMedia(media) { result in
                
                switch result {
                case .success(let files):
                    if files.isEmpty {
                        DispatchQueue.main.async {
                            //没有匹配到本地弹幕
                            completion(nil, DanmakuLoadError.notMatch)
                        }
                        return
                    }
                    
                    DanmakuManager.shared.downCustomDanmaku(files[0]) { result1 in
                        
                        switch result1 {
                        case .success(let url):
                            do {
                                let converResult = try DanmakuManager.shared.conver(url)
                                DispatchQueue.main.async {
                                    completion(converResult, nil)
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    completion(nil, DanmakuLoadError.converError)
                                }
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                completion(nil, error)
                            }
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
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
    
    /// 将弹幕数据转为可播放的弹幕模型
    /// - Parameter model: 弹幕数据
    /// - Returns: 弹幕模型
    private func conver(_ model: Comment) -> DanmakuEntity {
        let fontSize = CGFloat(Preferences.shared.danmakuFontSize)
        let danmakuEffectStyle = Preferences.shared.danmakuEffectStyle
        
        switch model.mode {
        case .normal:
            let aDanmaku = _ScrollDanmaku(text: model.message, textColor: model.color, font: .systemFont(ofSize: fontSize), effectStyle: danmakuEffectStyle, direction: .toLeft)
            aDanmaku.appearTime = model.time
            return aDanmaku
        case .bottom, .top:
            let position: FloatDanmaku.Position = model.mode == .bottom ? .atBottom : .atTop
            let aDanmaku = _FloatDanmaku(text: model.message, textColor: model.color, font: .systemFont(ofSize: fontSize), effectStyle: danmakuEffectStyle, position: position, lifeTime: 3)
            aDanmaku.appearTime = model.time
            return aDanmaku
        }
    }
}
