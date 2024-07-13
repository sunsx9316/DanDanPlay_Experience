//
//  Bangumi.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import Foundation

struct BangumiOnlineDatabase: Decodable {
    /// 网站名称
    @Default<String> var name: String
    
    /// 网址
    @Default<String> var url: String
}

struct BangumiTag: Decodable {
    /// 标签编号
    @Default<Int> var id: Int
    
    /// 标签内容
    @Default<String> var name: String
    
    /// 观众为此标签+1次数
    @Default<Int> var count: Int
}

/// 未看剧集
struct BangumiQueueIntro: Decodable {
    /// 作品编号
    @Default<Int> var animeId: Int
    
    /// 作品标题
    @Default<String> var animeTitle: String
    
    /// 最新一集的剧集标题
    @Default<String> var episodeTitle: String
    
    /// 剧集上映日期 （无小时分钟，当地时间）
    @Default<String> var airDate: String
    
    /// 海报图片地址
    @Default<String> var imageUrl: String
    
    /// 未看状态的说明 如“今天更新”，“昨天更新”，“有多集未看”等 ,
    @Default<String> var description: String
    
    /// 番剧是否在连载中
    @Default<Bool> var isOnAir: Bool
}

/// 新番列表
struct BangumiIntro: Decodable {
    /// 作品编号
    @Default<Int> var animeId: Int
    
    /// 作品标题
    @Default<String> var animeTitle: String
    
    /// 海报图片地址
    @Default<String> var imageUrl: String
    
    /// 搜索关键词
    @Default<String> var searchKeyword: String
    
    /// 是否正在连载中
    @Default<Bool> var isOnAir: Bool
    
    /// 周几上映，0代表周日，1-6代表周一至周六
    @Default<Int> var airDay: Int
    
    /// 当前用户是否已关注（无论是否为已弃番等附加状态）
    @Default<Bool> var isFavorited: Bool
    
    /// 是否为限制级别的内容（例如属于R18分级
    @Default<Bool> var isRestricted: Bool
    
    /// 番剧综合评分（综合多个来源的评分求出的加权平均值，0-10分）
    @Default<Double> var rating: Double
}

/// 动画番剧季度
struct BangumiSeason: Decodable {
    /// 年份
    @Default<Int> var year: Int
    
    /// 月份
    @Default<Int> var month: Int
    
    /// 季度名称
    @Default<String> var seasonName: String
}

struct BangumiEpisode: Decodable {
    /// 剧集ID（弹幕库编号）
    var episodeId: Int
    
    /// 剧集完整标题
    var episodeTitle: String
    
    /// 剧集短标题（可以用来排序，非纯数字，可能包含字母）
    var episodeNumber: String
    
    /// 上次观看时间（服务器时间，即北京时间）
    var lastWatched: Date?
    
    /// 本集上映时间（当地时间）
    var airDate: Date?
    
    private enum CodingKeys: CodingKey {
        case episodeId
        case episodeTitle
        case episodeNumber
        case lastWatched
        case airDate
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.episodeId = try container.decodeIfPresent(Int.self, forKey: .episodeId) ?? 0
        self.episodeTitle = try container.decodeIfPresent(String.self, forKey: .episodeTitle) ?? ""
        self.episodeNumber = try container.decodeIfPresent(String.self, forKey: .episodeNumber) ?? ""
        
        let formatter = DateFormatter.anix_YYYY_MM_dd_T_HH_mm_ssFormatter
        
        if let lastWatched = try container.decodeIfPresent(String.self, forKey: .lastWatched) {
            self.lastWatched = formatter.date(from: lastWatched)
        }
        
        if let airDate = try container.decodeIfPresent(String.self, forKey: .airDate) {
            self.airDate = formatter.date(from: airDate)
        }
    }
}

struct BangumiTitle: Decodable {
    /// 语言
    @Default<String> var language: String
    
    /// 标题
    @Default<String> var title: String
}

/// 站点的评分详情
struct BangumiRatingDetails: Decodable, DefaultValue {
    
    static var defaultValue: BangumiRatingDetails {
        return BangumiRatingDetails()
    }
    
    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        var intValue: Int?
        init?(intValue: Int) {
            return nil
        }
    }
    
    struct Item: Decodable {
        /// 来源
        @Default<String> var source: String
        
        /// 评分
        @Default<Double> var rating: Double
    }
    
    @Default<[Item]> var items: [Item]
    
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        
        var tempData = [Item]()
        
        for key in container.allKeys {
            let value = try container.decode(Double.self, forKey: key)
            
            let item = Item(source: key.stringValue, rating: value)
            tempData.append(item)
        }
        
        items = tempData
    }
    
    init() {
        self.items = []
    }
}


struct BangumiDetail: Decodable {
    
    /// 作品类型
    @Default<EpisodeType> var type: EpisodeType
    
    /// 类型描述
    @Default<String> var typeDescription: String
    
    /// 作品标题
    @Default<[BangumiTitle]> var titles: [BangumiTitle]
    
    /// 剧集列表
    @Default<[BangumiEpisode]> var episodes: [BangumiEpisode]
    
    /// 番剧简介
    @Default<String> var summary: String
    
    /// 番剧元数据（名称、制作人员、配音人员等）
    @Default<[String]> var metadata: [String]
    
    /// Bangumi.tv页面地址
    @Default<String> var bangumiUrl: String
    
    /// 用户个人评分（0-10）
    @Default<Double> var userRating: Double
    
    /// 关注状态 = ['favorited', 'finished', 'abandoned'],
    @Default<FavoriteStatus> var favoriteStatus: FavoriteStatus
    
    /// 用户对此番剧的备注/评论/标签
    @Default<String> var comment: String
    
    /// 各个站点的评分详情
    @Default<BangumiRatingDetails> var ratingDetails: BangumiRatingDetails
    
    /// 与此作品直接关联的其他作品（例如同一作品的不同季、剧场版、OVA等）
    @Default<[BangumiIntro]> var relateds: [BangumiIntro]
    
    /// 与此作品相似的其他作品
    @Default<[BangumiIntro]> var similars: [BangumiIntro]
    
    /// 标签列表
    @Default<[BangumiTag]> var tags: [BangumiTag]
    
    /// 此作品在其他在线数据库/网站的对应url
    @Default<[BangumiOnlineDatabase]> var onlineDatabases: [BangumiOnlineDatabase]
    
    /// 作品编号
    @Default<Int> var animeId: Int
    
    /// 作品标题
    @Default<String> var animeTitle: String
    
    /// 海报图片地址
    @Default<String> var imageUrl: String
    
    /// 搜索关键词
    @Default<String> var searchKeyword: String
    
    /// 是否正在连载中
    @Default<Bool> var isOnAir: Bool
    
    /// 周几上映，0代表周日，1-6代表周一至周六
    @Default<Int> var airDay: Int
    
    /// 当前用户是否已关注（无论是否为已弃番等附加状态）
    @Default<Bool> var isFavorited: Bool
    
    /// 是否为限制级别的内容（例如属于R18分级）
    @Default<Bool> var isRestricted: Bool
    
    /// 番剧综合评分（综合多个来源的评分求出的加权平均值，0-10分）
    @Default<Double> var rating: Double
}


struct BangumiDetailResponse: Decodable {
    
    /// 番剧详情
    var bangumi: BangumiDetail
}
