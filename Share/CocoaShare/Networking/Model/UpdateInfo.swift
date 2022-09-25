//
//  UpdateInfo.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/26.
//

import HandyJSON

struct UpdateInfo: HandyJSON {
    var url = ""
    
    /// "2022092601"
    var version = ""
    
    /// "1.0"
    var shortVersion = ""
    
    var desc = ""
    
    var hash = ""
    
    var forceUpdate = false
}
