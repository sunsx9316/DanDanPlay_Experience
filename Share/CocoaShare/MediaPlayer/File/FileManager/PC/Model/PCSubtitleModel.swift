//
//  PCSubtitleModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/7.
//

import Foundation

struct PCSubtitleCollectionModel: Decodable {
    
    @Default<[PCSubtitleModel]> var subtitles: [PCSubtitleModel]
    
}

struct PCSubtitleModel: Decodable {
    
    @Default<String> var fileName: String
    
    @Default<Int> var fileSize : Int
    
}
