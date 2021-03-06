//
//  MessageHandler.swift
//  dandanplay_native
//
//  Created by JimHuang on 2020/2/19.
//

import Foundation
import DDPShare

class MessageHandler {
    
    static func sendMessage(_ message: MessageProtocol) {
        if let delegate = UIApplication.shared.delegate as? AppDelegate,
            let vc = delegate.window.rootViewController as? MainViewController {
            vc.sendMessage(message)
        }
    }
    
    static func transferMessageToMainChannel(_ name: MessageType, _ messageData: [String : Any]) {
        if let delegate = UIApplication.shared.delegate as? AppDelegate,
            let vc = delegate.window.rootViewController as? MainViewController {
            vc.parseMessage(name, messageData)
        }
    }
}
