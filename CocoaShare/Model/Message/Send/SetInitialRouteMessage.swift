//
//  SetInitialRouteMessage.swift
//  dandanplay_native
//
//  Created by JimHuang on 2020/3/9.
//

import Foundation

public class SetInitialRouteMessage: BaseModel, MessageProtocol {
    public var routeName: String = ""
    var parameters: [String : Any]?
}
