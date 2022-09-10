//
//  Match.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import Foundation
import HandyJSON

enum EpisodeType: String, HandyJSONEnum, DefaultValue {
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

struct Match: HandyJSON {
    
    var episodeId = 0
    
    var animeId = 0
    
    var animeTitle = ""
    
    var episodeTitle = ""
    
    var type = EpisodeType.unknown
    
    var typeDescription = ""
    
    var shift = 0
}

struct MatchCollection: HandyJSON {
    var isMatched = false
    var collection = [Match]()
    
    mutating func mapping(mapper: HelpingMapper) {
        mapper <<<
            self.collection <-- "matches"
    }
    
}
