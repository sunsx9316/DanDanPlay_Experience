//
//  BaseModel.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/2.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import Foundation
import HandyJSON

open class BaseModel: HandyJSON {
    required public init() {}
    
    open func mapping(mapper: HelpingMapper) {
        
    }
    
    open func didFinishMapping() {
        
    }
}


open class BaseCollectionModel<T>: BaseModel {
    open var collection: [T]?;
}
