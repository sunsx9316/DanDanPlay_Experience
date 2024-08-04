//
//  SearchNetworkHandle.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import Foundation
import ANXLog

class SearchNetworkHandle {
    /// 搜索
    static func searchWithKeyword(_ keyword: String, completion: @escaping((SearchResult?, Error?) -> Void)) {
        var parameters = [String : String]()
        parameters["anime"] = keyword
        
        ANX.logInfo(.HTTP, "搜索 parameters: \(parameters)")
        NetworkManager.shared.getOnBaseURL(additionUrl: "/search/episodes", parameters: parameters) { result in
            switch result {
            case .success(let data):
                let result = Response<SearchResult>(with: data)
                
                /// 给搜索赋值标题
                if let searchCollection = result.result?.collection {
                    for item in searchCollection {
                        item.collection.forEach( { $0.animeTitle = item.animeTitle } )
                    }
                }
                
                completion(result.result, result.error)
                ANX.logInfo(.HTTP, "搜索 请求成功")
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "搜索 请求失败: \(error)")
            }
        }
    }
}
