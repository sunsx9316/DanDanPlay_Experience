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

struct SearchAnimeDetails: Decodable {
    /// 作品ID
    @Default<Int> var animeId: Int

    /// 作品ID（新）
    @Default<String> var bangumiId: String

    /// 作品标题
    @Default<String> var animeTitle: String

    /// 作品类型
    @Default<EpisodeType> var type: EpisodeType

    /// 类型描述
    @Default<String> var typeDescription: String

    /// 海报图片地址
    @Default<String> var imageUrl: String

    /// 上映日期
    var startDate: Date?

    /// 剧集总数
    @Default<Int> var episodeCount: Int

    /// 此作品的综合评分（0-10）
    @Default<Double> var rating: Double

    /// 当前用户是否已关注此作品
    @Default<Bool> var isFavorited: Bool

    private enum CodingKeys: CodingKey {
        case animeId
        case bangumiId
        case animeTitle
        case type
        case typeDescription
        case imageUrl
        case startDate
        case episodeCount
        case rating
        case isFavorited
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.animeId = try container.decodeIfPresent(Int.self, forKey: .animeId) ?? 0
        self.bangumiId = try container.decodeIfPresent(String.self, forKey: .bangumiId) ?? ""
        self.animeTitle = try container.decodeIfPresent(String.self, forKey: .animeTitle) ?? ""
        self.type = try container.decodeIfPresent(EpisodeType.self, forKey: .type) ?? .unknown
        self.typeDescription = try container.decodeIfPresent(String.self, forKey: .typeDescription) ?? ""
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl) ?? ""
        self.episodeCount = try container.decodeIfPresent(Int.self, forKey: .episodeCount) ?? 0
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        self.isFavorited = try container.decodeIfPresent(Bool.self, forKey: .isFavorited) ?? false

        let formatter = DateFormatter.anix_YYYY_MM_dd_T_HH_mm_ssFormatter
        if let startDate = try container.decodeIfPresent(String.self, forKey: .startDate) {
            self.startDate = formatter.date(from: startDate)
        }
    }
}

struct SearchBangumiDetails: Decodable {
    /// 作品ID
    @Default<Int> var animeId: Int

    /// 作品ID（新）
    @Default<String> var bangumiId: String

    /// 作品标题
    @Default<String> var animeTitle: String

    /// 作品类型
    @Default<EpisodeType> var type: EpisodeType

    /// 类型描述
    @Default<String> var typeDescription: String

    /// 海报图片地址
    @Default<String> var imageUrl: String

    /// 上映日期
    var startDate: Date?

    /// 剧集总数
    @Default<Int> var episodeCount: Int

    /// 此作品的综合评分（0-10）
    @Default<Double> var rating: Double

    /// 当前用户是否已关注此作品
    @Default<Bool> var isFavorited: Bool

    /// 搜索结果中的排名，从1开始递增
    @Default<Int> var rank: Int

    /// 搜索关键词
    @Default<String> var searchKeyword: String

    /// 是否正在连载中
    @Default<Bool> var isOnAir: Bool

    /// 是否为限制级别的内容
    @Default<Bool> var isRestricted: Bool

    /// 短简介（剧情简介或Staff简介）
    @Default<String> var intro: String

    private enum CodingKeys: CodingKey {
        case animeId
        case bangumiId
        case animeTitle
        case type
        case typeDescription
        case imageUrl
        case startDate
        case episodeCount
        case rating
        case isFavorited
        case rank
        case searchKeyword
        case isOnAir
        case isRestricted
        case intro
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.animeId = try container.decodeIfPresent(Int.self, forKey: .animeId) ?? 0
        self.bangumiId = try container.decodeIfPresent(String.self, forKey: .bangumiId) ?? ""
        self.animeTitle = try container.decodeIfPresent(String.self, forKey: .animeTitle) ?? ""
        self.type = try container.decodeIfPresent(EpisodeType.self, forKey: .type) ?? .unknown
        self.typeDescription = try container.decodeIfPresent(String.self, forKey: .typeDescription) ?? ""
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl) ?? ""
        self.episodeCount = try container.decodeIfPresent(Int.self, forKey: .episodeCount) ?? 0
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        self.isFavorited = try container.decodeIfPresent(Bool.self, forKey: .isFavorited) ?? false
        self.rank = try container.decodeIfPresent(Int.self, forKey: .rank) ?? 0
        self.searchKeyword = try container.decodeIfPresent(String.self, forKey: .searchKeyword) ?? ""
        self.isOnAir = try container.decodeIfPresent(Bool.self, forKey: .isOnAir) ?? false
        self.isRestricted = try container.decodeIfPresent(Bool.self, forKey: .isRestricted) ?? false
        self.intro = try container.decodeIfPresent(String.self, forKey: .intro) ?? ""

        let formatter = DateFormatter.anix_YYYY_MM_dd_T_HH_mm_ssFormatter
        if let startDate = try container.decodeIfPresent(String.self, forKey: .startDate) {
            self.startDate = formatter.date(from: startDate)
        }
    }
}

struct SearchBangumiResponse: Decodable {
    /// 搜索结果
    @Default<[SearchBangumiDetails]> var bangumis: [SearchBangumiDetails]
}
