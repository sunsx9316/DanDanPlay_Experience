//
//  PCQRModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/2.
//

import Foundation
import HandyJSON

struct PCQRModel: HandyJSON {
    
    var ip = [String]()
    
    var port = 0
    
    var tokenRequired = false
    
    var name = ""
    
    mutating func mapping(mapper: HelpingMapper) {
        mapper <<<
            name <-- "machineName"
    }
    
}
