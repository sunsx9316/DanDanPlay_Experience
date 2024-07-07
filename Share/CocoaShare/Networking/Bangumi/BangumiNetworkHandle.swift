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
}

