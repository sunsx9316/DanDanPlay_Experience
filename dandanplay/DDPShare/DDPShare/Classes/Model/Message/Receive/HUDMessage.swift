//
//  HUDMessage.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/3.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import HandyJSON

class HUDMessage: BaseModel {
    enum Style: String, HandyJSONEnum {
        case tips
        case progress
    }
    
    var style = Style.tips
    var text = ""
    var progress: Float = 0.0
    var isDismiss = false
    var key = ""
}
