//
//  LoadDanmakuMessage.swift
//  dandanplay_native
//
//  Created by JimHuang on 2020/2/19.
//

open class LoadDanmakuMessage: BaseModel {
    open var danmakuCollection: DanmakuCollectionModel?
    open var mediaId = ""
    open var title: String?
    open var playImmediately = false
    open var episodeId = 0
}
