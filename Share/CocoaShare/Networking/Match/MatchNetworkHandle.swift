//
//  MatchNetworkHandle.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import Foundation
import ANXLog


/// 文件匹配模式
enum MatchMode: String {
    case hashAndFileName = "hashAndFileName"
    case fileNameOnly = "fileNameOnly"
    case hashOnly = "hashOnly"
}

class MatchNetworkHandle {
    
    /// 匹配文件，当匹配结果为1时，则自动获取弹幕
    /// - Parameters:
    ///   - file: 文件
    ///   - progress: 当前进度
    ///   - matchCompletion: 当匹配结果 > 1时回调，不再继续往下走
    ///   - getDanmakuCompletion: 获取弹幕回调
    static func matchAndGetDanmakuWithFile(_ file: File,
                                           progress: FileProgressAction? = nil,
                                           matchCompletion: @escaping((MatchCollection?, Error?) -> Void),
                                           getDanmakuCompletion: @escaping((CommentCollection?, _ episodeId: Int, Error?) -> Void)) {
        
        ANX.logInfo(.HTTP, "根据文件直接搜索弹幕 file: \(file)")
        
        self.match(with: file) { (progressValue) in
            progress?(0.5 * progressValue)
        } completion: { (collection, error) in
            
            if let error = error {
                progress?(1)
                matchCompletion(collection, error)
                return
            }
            
            //精确匹配
            if collection?.isMatched == true &&
                collection?.collection.count == 1 &&
                Preferences.shared.fastMatch {
                progress?(0.7)
                let matched = collection!.collection[0]
                
                ANX.logInfo(.HTTP, "根据文件直接搜索弹幕 精确匹配 matched: \(matched)")
                
                CommentNetworkHandle.getDanmaku(with: matched.episodeId) { damakus, error in
                    progress?(1)
                    getDanmakuCompletion(damakus, matched.episodeId, error)
                }
            } else {
                progress?(1)
                matchCompletion(collection, error)
                ANX.logInfo(.HTTP, "根据文件直接搜索弹幕 请求成功 collection数量: \(String(describing: collection?.collection.count))")
            }
        }
    }
    
    
    
    /// 根据文件请求匹配的结果
    /// - Parameters:
    ///   - file: 文件
    ///   - matchMode: 匹配模式
    ///   - parseDataProgress: 匹配进度
    ///   - completion: 完成回调
    static func match(with file: File,
                      matchMode: MatchMode = .hashAndFileName,
                      parseDataProgress: FileProgressAction? = nil,
                      completion: @escaping((MatchCollection?, Error?) -> Void)) {
        
        let requestMatchWithFileHashBlock = { (_ fileHash: String) in
            
            var parameters = [String : String]()
            parameters["fileName"] = file.fileName
            parameters["fileHash"] = fileHash
            parameters["fileSize"] = "\(file.fileSize)"
            parameters["matchMode"] = matchMode.rawValue
            
            ANX.logInfo(.HTTP, "根据文件返回匹配的结果 请求参数: \(parameters)")
            
            NetworkManager.shared.postOnBaseURL(additionUrl: "/match", parameters: parameters) { result in
                switch result {
                case .success(let data):
                    let result = Response<MatchCollection>(with: data)
                    
                    let collection = result.result
                    
                    /// 精确匹配，缓存结果
                    if collection?.isMatched == true && collection?.collection.count == 1 {
                        CacheManager.shared.setMatchResultWithHash(fileHash, data: data)
                    }
                    
                    completion(collection, result.error)
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 请求成功")
                case .failure(let error):
                    completion(nil, error)
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 请求失败: \(error)")
                }
            }
        }
        
        if Preferences.shared.fastMatch,
           let hash = CacheManager.shared.matchHashWithFile(file) {
            ANX.logInfo(.HTTP, "根据文件返回匹配的结果 快速匹配 hash：\(hash)")
            
            if let data = CacheManager.shared.matchResultWithHash(hash) {
                let result = Response<MatchCollection>(with: data)
                
                completion(result.result, nil)
                ANX.logInfo(.HTTP, "根据缓存返回匹配的结果 请求成功")
            } else {
                requestMatchWithFileHashBlock(hash)
            }
            
        } else {
            ANX.logInfo(.HTTP, "根据文件返回匹配的结果 获取文件解析字节")
            file.getFileHashWithProgress(parseDataProgress) { result in
                switch result {
                case .failure(let error):
                    completion(nil, error)
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 失败 error: \(error)")
                case .success(let hash):
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 成功 hash: \(hash)")
                    CacheManager.shared.setMatchHashWithFile(file, hash: hash)
                    requestMatchWithFileHashBlock(hash)
                }
            }
        }
    }
    
}
