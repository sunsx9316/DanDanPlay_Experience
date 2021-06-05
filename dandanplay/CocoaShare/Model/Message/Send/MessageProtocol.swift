//
//  BaseMessage.swift
//  dandanplay_native
//
//  Created by JimHuang on 2020/2/16.
//

import Foundation
import HandyJSON

public protocol MessageProtocol {
    var messageName: String { get }
    var messageData: [String : Any]? { get }
}

public extension MessageProtocol where Self: HandyJSON {
    var messageName: String {
        return "\(type(of: self))"
    }
    
    var messageData: [String : Any]? {
        return self.toJSON()
    }
}
