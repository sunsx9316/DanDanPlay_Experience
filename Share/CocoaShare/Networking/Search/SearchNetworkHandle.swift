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

    /// 根据标签搜索最匹配的作品
    /// - Parameters:
    ///   - tags: 标签列表，用英文逗号分隔，每个标签长度不超过50个字符，数量不超过10个。区分大小写，不支持模糊查询。
    ///   - completion: 完成回调
    static func searchByTag(_ tags: String, completion: @escaping((SearchBangumiResponse?, Error?) -> Void)) {
        let parameters = ["tags": tags]

        ANX.logInfo(.HTTP, "标签搜索 tags: \(tags)")
        NetworkManager.shared.getOnBaseURL(additionUrl: "/search/tag", parameters: parameters) { result in
            switch result {
            case .success(let data):
                let rsp = Response<SearchBangumiResponse>(with: data)
                completion(rsp.result, rsp.error)
                ANX.logInfo(.HTTP, "标签搜索 请求成功")
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "标签搜索 请求失败: \(error)")
            }
        }
    }
}
