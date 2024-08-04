//
//  MatchInfo.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/4.
//

import Foundation

/// 匹配信息，用于在播放页展示
protocol MatchInfo {
    var matchId: Int { get }
    var matchDesc: String { get }
}

/// 媒体匹配信息，用于在匹配/搜索页展示
protocol MediaMatchItem: MatchInfo {
    
    var items: [MediaMatchItem]? { get }
    
    var title: String { get }
    
    var episodeId: Int? { get }
    
    var typeDesc: String? { get }
}

extension Match: MatchInfo {
    var matchId: Int {
        return self.episodeId
    }
    
    var matchDesc: String {
        return self.animeTitle + "-" + self.episodeTitle
    }
}


extension Search: MediaMatchItem {
    var matchId: Int {
        return self.id
    }
    
    var matchDesc: String {
        return self.animeTitle + "-" + self.episodeTitle
    }
    
    var episodeId: Int? {
        return self.id
    }
    
    var items: [MediaMatchItem]? {
        return nil
    }
    
    var title: String {
        return self.episodeTitle
    }
    
    var typeDesc: String? {
        return nil
    }
}

extension SearchCollection: MediaMatchItem {
    var matchId: Int {
        return 0
    }
    
    var matchDesc: String {
        return ""
    }
    
    var items: [MediaMatchItem]? {
        return self.collection
    }
    
    var title: String {
        return self.animeTitle
    }
    
    var episodeId: Int? {
        return nil
    }
    
    var typeDesc: String? {
        return self.typeDescription
    }
}
