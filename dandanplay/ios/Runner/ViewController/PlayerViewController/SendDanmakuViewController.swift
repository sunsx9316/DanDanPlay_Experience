//
//  SendDanmakuViewController.swift
//  Runner
//
//  Created by jimhuang on 2020/11/29.
//

import UIKit
import DDPShare

class SendDanmakuViewController: MessageViewController {
    
    var onTouchSendButtonCallBack: ((String, SendDanmakuViewController) -> Void)?
    
    override init(project: FlutterDartProject?, initialRoute: String? = "sendDanmaku", nibName: String?, bundle nibBundle: Bundle?) {
        super.init(project: project, initialRoute: initialRoute, nibName: nibName, bundle: nibBundle)
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func parseMessage(_ name: MessageType, _ messageData: [String : Any]) {
        switch name {
        case .naviBack:
            self.navigationController?.popViewController(animated: true)
        case .inputDanmaku:
            if let message = InputDanmakuMessage.deserialize(from: messageData) {
                self.onTouchSendButtonCallBack?(message.message, self)
            }
        default:
            break
        }
    }
}
