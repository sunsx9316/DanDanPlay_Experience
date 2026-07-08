//
//  Match.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import Foundation

enum EpisodeType: String, Codable, DefaultValue {
    static let defaultValue = EpisodeType.unknown

    case tvSeries = "tvseries"
    case tvSpecial = "tvspecial"
    case ova
    case movie
    case musicvideo
    case web
    case other
    case jpMovie = "jpmovie"
    case jpDrama = "jpdrama"
    case unknown
    case tmdbTV = "tmdbtv"
    case tmdbMovie = "tmdbmovie"

    var displayName: String {
        switch self {
        case .tvSeries: return "TV 动画"
        case .tvSpecial: return "TV 特别篇"
        case .ova: return "OVA"
        case .movie: return "剧场版"
        case .musicvideo: return "MV"
        case .web: return "网络动画"
        case .other: return "其他"
        case .jpMovie: return "日影"
        case .jpDrama: return "日剧"
        case .unknown: return ""
        case .tmdbTV: return "TMDB 电视剧"
        case .tmdbMovie: return "TMDB 电影"
        }
    }
}

struct Match: Decodable {
    
    @Default<Int> var episodeId: Int
    
    @Default<Int> var animeId: Int
    
    @Default<String> var animeTitle: String
    
    @Default<String> var episodeTitle: String
    
    @Default<EpisodeType> var type: EpisodeType
    
    @Default<String> var typeDescription: String
    
    @Default<Int> var shift: Int
}

struct MatchCollection: Decodable {
    @Default<Bool> var isMatched: Bool
    @Default<[Match]> var collection: [Match]
    
    private enum CodingKeys: String, CodingKey {
        case collection = "matches"
        case isMatched
    }
    
}
