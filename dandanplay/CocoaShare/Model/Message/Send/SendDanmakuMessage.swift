//
//  SendDanmakuMessage.swift
//  DDPShare
//
//  Created by JimHuang on 2020/4/12.
//

import Foundation

open class SendDanmakuMessage: BaseModel, MessageProtocol {
    open var danmaku: DanmakuModel?
    open var episodeId = 0
    
    public var messageData: [String : Any]? {
        if let danmaku = danmaku {
            return ["time" : danmaku.time,
                    "mode" : danmaku.mode.rawValue,
                    "color" : danmaku.color.rgbValue,
                    "comment" : danmaku.message,
                    "episodeId" : episodeId]
        }
        
        return nil
    }
}
