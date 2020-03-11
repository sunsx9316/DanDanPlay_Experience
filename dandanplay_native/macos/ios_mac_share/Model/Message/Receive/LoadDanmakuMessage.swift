//
//  LoadDanmakuMessage.swift
//  dandanplay_native
//
//  Created by JimHuang on 2020/2/19.
//

import Cocoa

open class LoadDanmakuMessage: BaseModel {
    open var danmakuCollection: DanmakuCollectionModel?
    open var mediaId = ""
    open var title: String?
}
