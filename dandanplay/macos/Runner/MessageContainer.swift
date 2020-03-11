//
//  MessageContainer.swift
//  Runner
//
//  Created by JimHuang on 2020/3/5.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation
import dandanplay_native
import HandyJSON

class MessageContainer<T>: BaseModel {
    var name = ""
    var message: T?
    
    override func mapping(mapper: HelpingMapper) {
        mapper <<<
            message <-- "data"
    }
}
