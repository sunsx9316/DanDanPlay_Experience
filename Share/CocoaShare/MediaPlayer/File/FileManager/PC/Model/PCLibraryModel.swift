//
//  PCLibraryModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/1.
//

import UIKit

struct PCLibraryModel: Decodable {

    @Default<String> var id: String
    
    @Default<Int> var animeId: Int
    
    @Default<Int> var episodeId: Int
    
    @Default<String> var animeTitle: String
    
    @Default<String> var episodeTitle: String
    
    @Default<String> var hash: String
    
    @Default<String> var name: String
    
    @Default<Int> var size: Int
    
    @Default<String> var path: String
    
    private enum CodingKeys: String, CodingKey {
        
        case animeId = "AnimeId"
        
        case episodeId = "EpisodeId"
        
        case animeTitle = "AnimeTitle"
        
        case episodeTitle = "EpisodeTitle"
        
        case id = "Id"
        
        case hash = "Hash"
        
        case name = "Name"
        
        case size = "Size"
        
        case path = "Path"
    }
    
}
