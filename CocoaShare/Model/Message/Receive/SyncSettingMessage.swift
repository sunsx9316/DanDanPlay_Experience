//
//  SyncSettingMessage.swift
//  DDPShare
//
//  Created by JimHuang on 2020/3/22.
//

open class SyncSettingMessage: BaseModel, MessageProtocol {
    open var key = ""
    open var value: Any?
}
