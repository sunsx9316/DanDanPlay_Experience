//
//  BangumiNetworkHandle.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import Foundation

class BangumiNetworkHandle {

    /// 获取番剧详情
    /// - Parameters:
    ///   - animateId: 动画id
    ///   - completion: 完成回调
    static func detail(animateId: Int, completion: @escaping((BangumiDetailResponse?, Error?) -> Void)) {
        NetworkManager.shared.getOnBaseURL(additionUrl: "/bangumi/\(animateId)") { result in
            switch result {
            case .success(let data):
                let rsp = Response<BangumiDetailResponse>(with: data)
                completion(rsp.result, rsp.error)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }

    /// 获取指定番剧的短评论/吐槽列表
    /// - Parameters:
    ///   - bangumiId: 作品编号（支持数字 animeId 或字符串 bangumiId）
    ///   - page: 页码，从 0 开始，最大为 9
    ///   - completion: 完成回调
    static func comments(bangumiId: String, page: Int = 0, completion: @escaping((BangumiCommentsResponse?, Error?) -> Void)) {
        let params = ["page": String(page)]
        NetworkManager.shared.getOnBaseURL(additionUrl: "/bangumi/\(bangumiId)/comments", parameters: params) { result in
            switch result {
            case .success(let data):
                let rsp = Response<BangumiCommentsResponse>(with: data)
                completion(rsp.result, rsp.error)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
}

