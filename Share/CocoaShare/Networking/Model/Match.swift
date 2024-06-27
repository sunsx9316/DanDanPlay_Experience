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
