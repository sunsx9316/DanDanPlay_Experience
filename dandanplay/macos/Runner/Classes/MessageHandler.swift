//
//  MessageHandler.swift
//  dandanplay_native
//
//  Created by JimHuang on 2020/2/19.
//

import Foundation
import dandanplay_native

class MessageHandler {
    
    static func sendMessage(_ message: MessageProtocol) {
        if let delegate = NSApp.delegate as? AppDelegate,
            let vc = delegate.mainFlutterWindow.contentViewController as? MainViewController {
            vc.sendMessage(message)
        }
    }
    
    
}
