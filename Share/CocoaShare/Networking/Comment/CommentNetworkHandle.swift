//
//  CommentNetworkHandle.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import Foundation
import ANXLog


/// 语言转换枚举
enum LanConvert: Int {
    /// 不转化
    case noCover = 0
    /// 转为简体
    case toSimplified = 1
    
    /// 转为繁体
    case toTraditional
}

class CommentNetworkHandle {
    
    /// 根据文件获取弹幕
    /// - Parameters:
    ///   - episodeId: 剧集id
    ///   - from: 起始弹幕编号，忽略此编号以前的弹幕。默认值为0
    ///   - withRelated: 是否同时获取关联的第三方弹幕。默认值为true
    ///   - lanConvert: 中文简繁转换
    ///   - completion: 完成回调
    static func getDanmaku(with episodeId: Int,
                           from: Int? = nil,
                           withRelated: Bool = true,
                           lanConvert: LanConvert? = nil,
                           completion: @escaping((CommentCollection?, Error?) -> Void)) {
        
        var parameters = [String : String]()
        parameters["withRelated"] = withRelated ? "true" : "false"
        
        if let from = from {
            parameters["from"] = "\(from)"
        }
        
        if let lanConvert = lanConvert {
            parameters["chConvert"] = "\(lanConvert.rawValue)"
        }
        
        let md5Str = ("\(parameters)" as NSString).md5() ?? ""
        if let data = CacheManager.shared.danmakuCacheWithEpisodeId(episodeId, parametersHash: md5Str) {
            ANX.logInfo(.HTTP, "根据文件下载弹幕 匹配到缓存 episodeId: \(episodeId) md5Str: \(md5Str)")
            let result = Response<CommentCollection>(with: data)
            completion(result.result, nil)
            return
        }
        
        ANX.logInfo(.HTTP, "根据文件下载弹幕 请求 parameters: \(parameters)")
        
        NetworkManager.shared.getOnBaseURL(additionUrl: "/comment/\(episodeId)", parameters: parameters) { result in
            switch result {
            case .success(let data):
                let result = Response<CommentCollection>(with: data)
                if result.error == nil {
                    CacheManager.shared.setDanmakuCacheWithEpisodeId(episodeId, parametersHash: md5Str, data: data)
                }
                completion(result.result, result.error)
                ANX.logInfo(.HTTP, "根据文件下载弹幕 请求成功")
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "根据文件下载弹幕 请求失败: \(error)")
            }
        }
    }
}
