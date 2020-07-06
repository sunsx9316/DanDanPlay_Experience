//
//  AppVersionMessage.swift
//  DDPShare
//
//  Created by JimHuang on 2020/3/29.
//

import Foundation

open class AppVersionMessage: BaseModel, MessageProtocol {
    open var url: String?
    open var version: String?
    open var shortVersion: String?
    open var desc: String?
    open var hash: String?
    open var forceUpdate = false
    open var byManual = false;
}
