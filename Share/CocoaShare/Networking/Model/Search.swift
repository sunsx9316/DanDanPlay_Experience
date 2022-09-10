//
//  Search.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/8.
//

import Foundation
import HandyJSON

struct Search: HandyJSON {
    
    /// 剧集ID（弹幕库编号）
    var id = 0
    
    /// 剧集标题
    var episodeTitle = ""
    
    mutating func mapping(mapper: HelpingMapper) {
        mapper <<<
            self.id <-- "episodeId"
    }
}

struct SearchCollection: HandyJSON {
    
    /// 作品编号
    var animeId = 0
    
    ///  作品标题
    var animeTitle = ""
    
    /// 作品类型
    var type = EpisodeType.unknown
    
    /// 类型描述
    var typeDescription = ""
    
    /// 此作品的剧集列表
    var collection = [Search]()
    
    mutating func mapping(mapper: HelpingMapper) {
        mapper <<<
            self.collection <-- "episodes"
    }
}

struct SearchResult: HandyJSON {
    
    /// 是否有更多未显示的搜索结果，当结果集过大时，hasMore属性为true，这时客户端应该提示用户填写更详细的信息以缩小搜索范围。
    var hasMore = false
    
    var collection = [SearchCollection]()
    
    mutating func mapping(mapper: HelpingMapper) {
        mapper <<<
            self.collection <-- "animes"
    }
}
