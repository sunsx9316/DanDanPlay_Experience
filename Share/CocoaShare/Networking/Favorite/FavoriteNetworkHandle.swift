//
//  FavoriteNetworkHandle.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/13.
//

import Foundation

class FavoriteNetworkHandle {
    
    /// 获取用户关注的动画作品
    /// - Parameter completion: 完成回调
    static func getFavoriteList(completion: @escaping((UserFavoriteResponse?, Error?) -> Void)) {
        NetworkManager.shared.getOnBaseURL(additionUrl: "/favorite") { result in
            switch result {
            case .success(let data):
                let rsp = Response<UserFavoriteResponse>(with: data)
                completion(rsp.result, rsp.error)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
    /// 喜欢/取消喜欢
    /// - Parameters:
    ///   - animateId: 动画id
    ///   - isLike: 是否喜欢
    ///   - completion: 完成回调
    static func changeFavorite(animateId: Int, isLike: Bool, completion: @escaping((Error?) -> Void)) {
        if isLike {
            change(animateId: animateId, favoriteStatus: .favorited, completion: completion)
        } else {
            NetworkManager.shared.deleteOnBaseURL(additionUrl: "/favorite/\(animateId)") { result in
                switch result {
                case .success(let data):
                    let decoder = JSONDecoder()
                    var error = try? decoder.decode(ResponseError.self, from: data)
                    completion(error?.errorCode == 0 ? nil : error)
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }
    
    
    /// 修改关注状态
    /// - Parameters:
    ///   - animateId: 动画id
    ///   - favoriteStatus: 喜欢状态
    ///   - rating: 评分
    ///   - comment: 添加评论
    ///   - completion: 完成回调
    static private func change(animateId: Int, favoriteStatus: FavoriteStatus? = nil, rating: Int? = nil, comment: String? = nil, completion: @escaping((Error?) -> Void)) {
        
        var parameters = [String : String]()
        parameters["animeId"] = "\(animateId)"
        parameters["favoriteStatus"] = favoriteStatus?.rawValue
        if let rating = rating {
            parameters["rating"] = "\(rating)"
        }
        parameters["comment"] = comment
        
        NetworkManager.shared.postOnBaseURL(additionUrl: "/favorite", parameters: parameters) { result in
            switch result {
            case .success(let data):
                let decoder = JSONDecoder()
                var error = try? decoder.decode(ResponseError.self, from: data)
                completion(error?.errorCode == 0 ? nil : error)
            case .failure(let error):
                completion(error)
            }
        }
    }
}
