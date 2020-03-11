//
//  MessageContainer.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/3.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import UIKit
import HandyJSON

class MessageContainer<T>: BaseModel {
    var name = ""
    var message: T?
    
    override func mapping(mapper: HelpingMapper) {
        mapper <<<
            message <-- "data"
    }
}
