//
//  IPModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/20.
//

import Foundation
import Alamofire
import HandyJSON

struct IPResponse: HandyJSON {
    
    var answers = [IPModel]()
    
    mutating func mapping(mapper: HelpingMapper) {
        mapper <<<
            self.answers <-- "Answer"
    }
    
}

struct IPModel: HandyJSON {
    
    var name = ""
    
    var data = ""
    
    mutating func didFinishMapping() {
        self.data = self.data.replacingOccurrences(of: "\"", with: "")
    }
}
