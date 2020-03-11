//
//  BaseModel.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/2.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import Foundation
import HandyJSON

class BaseModel: HandyJSON {
    required init() {}
    
    func mapping(mapper: HelpingMapper) {
        
    }
    
    func didFinishMapping() {
        
    }
}


class BaseCollectionModel<T>: BaseModel {
    var collection: [T]?;
}
