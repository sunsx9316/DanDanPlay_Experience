//
//  HomePageNetworkHandle.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import Foundation

class HomePageNetworkHandle {
    
    /// 请求首页数据
    /// - Parameters:
    ///   - filterAdultContent: 过滤18x内容，默认true
    ///   - completion: 完成回调
    static func homePage(filterAdultContent: Bool = true,
                         completion: @escaping((Homepage?, Error?) -> Void)) {
        var parameters = [String : Bool]()
        parameters["filterAdultContent"] = true
        
        NetworkManager.shared.getOnBaseURL(additionUrl: "/homePage", parameters: parameters) { result in
            switch result {
            case .success(let data):
                let result = Response<Homepage>(with: data)
                completion(result.result, result.error)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
}
