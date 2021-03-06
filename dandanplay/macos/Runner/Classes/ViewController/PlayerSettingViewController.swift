//
//  PlayerSettingViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/3/5.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa
import FlutterMacOS

class PlayerSettingViewController: MessageViewController {
    
    convenience init() {
        self.init(routeName: "playerSetting")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func parseMessage(_ name: MessageType, _ messageData: [String : Any]) {
        MessageHandler.transferMessageToMainChannel(name, messageData)
    }
    
}
