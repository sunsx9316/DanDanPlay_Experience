//
//  PCLibraryModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/1.
//

import UIKit
import HandyJSON

struct PCLibraryModel: HandyJSON {

    var id = ""
    
    var animeId = 0
    
    var episodeId = 0
    
    var animeTitle = ""
    
    var episodeTitle = ""
    
    var hash = ""
    
    var name = ""
    
    var size = 0
    
    var path = ""
    
    mutating func mapping(mapper: HelpingMapper) {
        
        mapper <<<
            animeId <-- "AnimeId"
        
        mapper <<<
            episodeId <-- "EpisodeId"
        
        mapper <<<
            animeTitle <-- "AnimeTitle"
        
        mapper <<<
            episodeTitle <-- "EpisodeTitle"
        
        mapper <<<
            id <-- "Id"
        
        mapper <<<
            hash <-- "Hash"
        
        mapper <<<
            name <-- "Name"
        
        mapper <<<
            size <-- "Size"
        
        mapper <<<
            path <-- "Path"
    }
    
}
