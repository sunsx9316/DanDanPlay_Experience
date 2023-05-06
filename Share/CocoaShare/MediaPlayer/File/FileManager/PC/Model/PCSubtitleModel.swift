//
//  PCSubtitleModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/7.
//

import Foundation
import HandyJSON

struct PCSubtitleCollectionModel: HandyJSON {
    var subtitles = [PCSubtitleModel]()
}

struct PCSubtitleModel: HandyJSON {
    
    var fileName = ""
    
    var fileSize = 0
    
}
