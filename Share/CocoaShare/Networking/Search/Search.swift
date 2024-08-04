//
//  Search.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/8.
//

import Foundation

class Search: Decodable {
    
    /// 剧集ID（弹幕库编号）
    @Default<Int> var id: Int
    
    /// 剧集标题
    @Default<String> var episodeTitle: String
    
    ///  作品标题
    var animeTitle: String = ""
    
    private enum CodingKeys: String, CodingKey {
        case id = "episodeId"
        case episodeTitle
    }
}

class SearchCollection: Decodable {
    
    /// 作品编号
    @Default<Int> var animeId: Int
    
    ///  作品标题
    @Default<String> var animeTitle: String
    
    /// 作品类型
    @Default<EpisodeType> var type: EpisodeType
    
    /// 类型描述
    @Default<String> var typeDescription: String
    
    /// 此作品的剧集列表
    @Default<[Search]> var collection: [Search]
    
    private enum CodingKeys: String, CodingKey {
        case collection = "episodes"
        case animeId, animeTitle, type, typeDescription
    }
}

class SearchResult: Decodable {
    
    /// 是否有更多未显示的搜索结果，当结果集过大时，hasMore属性为true，这时客户端应该提示用户填写更详细的信息以缩小搜索范围。
    @Default<Bool> var hasMore: Bool
    
    @Default<[SearchCollection]> var collection: [SearchCollection]
    
    private enum CodingKeys: String, CodingKey {
        case collection = "animes"
        case hasMore
    }
}
