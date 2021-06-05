//
//  HUDMessage.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/3.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import HandyJSON

public class HUDMessage: BaseModel {
    public enum Style: String, HandyJSONEnum {
        case tips
        case progress
    }
    
    public var style = Style.tips
    public var text = ""
    public var progress: Double = 0.0
    public var isDismiss = false
    public var key = ""
}
