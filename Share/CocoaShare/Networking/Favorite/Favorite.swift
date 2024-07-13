//
//  Favorite.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/13.
//

import Foundation

struct UserFavoriteResponse: Decodable {
    /// 关注列表
    @Default<[UserFavoriteItem]> var favorites: [UserFavoriteItem]
}

enum FavoriteStatus: String, Decodable, DefaultValue {
    
    static var defaultValue = FavoriteStatus.unknow
    
    case unknow
    /// 已关注
    case favorited = "favorited"
    /// 已看完
    case finished = "finished"
    /// 已弃番
    case abandoned = "abandoned"
}

struct UserFavoriteItem: Decodable {
    /// 作品编号
    var animeId: Int
    /// 作品标题
    var animeTitle: String
    /// 作品类型 = ['tvseries', 'tvspecial', 'ova','movie', 'usicvideo', 'web', 'other', 'jpmovie', 'jpdrama', 'unknown']
    var type: EpisodeType
    /// 上次关注的时间
    var lastFavoriteTime: Date?
    /// 上次剧集更新的时间
    var lastAirDate: Date?
    /// 上次播放作品相关剧集的时间
    var lastWatchTime: Date?
    /// 海报图片地址
    var imageUrl: String
    /// 此作品的总集数
    var episodeTotal: Int
    /// 当前已看的集数
    var episodeWatched: Int
    /// 番剧首话上映日期
    var startDate: Date?
    /// 此作品是否正在连载中
    var isOnAir: Bool
    /// 关注状态 = ['favorited', 'finished', 'abandoned']
    var favoriteStatus: FavoriteStatus
    /// 用户给此作品的评分（1-10 分，0 代表未评分）
    var userRating: Int
    /// 此番剧的综合评分（0-10 分）
    var rating: Double
    
    private enum CodingKeys: CodingKey {
        case animeId
        case animeTitle
        case type
        case lastFavoriteTime
        case lastAirDate
        case lastWatchTime
        case imageUrl
        case episodeTotal
        case episodeWatched
        case startDate
        case isOnAir
        case favoriteStatus
        case userRating
        case rating
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.animeId = try container.decodeIfPresent(Int.self, forKey: .animeId) ?? 0
        self.animeTitle = try container.decodeIfPresent(String.self, forKey: .animeTitle) ?? ""
        self.type = try container.decodeIfPresent(EpisodeType.self, forKey: .type) ?? .unknown
        
        let dateFormatter = DateFormatter.anix_YYYY_MM_dd_T_HH_mm_ss_SSSFormatter
        
        if let lastFavoriteTime = try container.decodeIfPresent(String.self, forKey: .lastFavoriteTime) {
            self.lastFavoriteTime = dateFormatter.date(from: lastFavoriteTime)
        }
        
        if let lastAirDate = try container.decodeIfPresent(String.self, forKey: .lastAirDate) {
            self.lastAirDate = dateFormatter.date(from: lastAirDate)
        }
        
        if let lastWatchTime = try container.decodeIfPresent(String.self, forKey: .lastWatchTime) {
            self.lastWatchTime = dateFormatter.date(from: lastWatchTime)
        }
        
        if let startDate = try container.decodeIfPresent(String.self, forKey: .startDate) {
            self.startDate = dateFormatter.date(from: startDate)
        }
        
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl) ?? ""
        self.episodeTotal = try container.decodeIfPresent(Int.self, forKey: .episodeTotal) ?? 0
        self.episodeWatched = try container.decodeIfPresent(Int.self, forKey: .episodeWatched) ?? 0
        self.isOnAir = try container.decodeIfPresent(Bool.self, forKey: .isOnAir) ?? false
        self.favoriteStatus = try container.decodeIfPresent(FavoriteStatus.self, forKey: .favoriteStatus) ?? .unknow
        self.userRating = try container.decodeIfPresent(Int.self, forKey: .userRating) ?? 0
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating) ?? 0
    }
}
