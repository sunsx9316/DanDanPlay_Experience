//
//  PlayerSettingViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/7/22.
//

import UIKit

class PlayerSettingViewController: MessageViewController {
    
    override init(project: FlutterDartProject?, nibName: String?, bundle nibBundle: Bundle?) {
        super.init(project: project, nibName: nibName, bundle: nibBundle)
        setInitialRoute("playerSetting")
    }
    
    override init(engine: FlutterEngine, nibName: String?, bundle nibBundle: Bundle?) {
        super.init(engine: engine, nibName: nibName, bundle: nibBundle)
        setInitialRoute("playerSetting")
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setInitialRoute("playerSetting")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func parseMessage(_ name: MessageType, _ messageData: [String : Any]) {
        MessageHandler.transferMessageToMainChannel(name, messageData)
    }
    
}
