//
//  MatchMessageViewController.swift
//  Runner
//
//  Created by jimhuang on 2021/1/9.
//

import UIKit

class MatchMessageViewController: MessageViewController {
    
    var parseMessageCallBack: ((MessageType, [String : Any]) -> Void)?

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(with msg: ReloadMatchWidgetMessage) {
        super.init(project: nil, initialRoute: "match", nibName: nil, bundle: nil)
        
        self.setFlutterViewDidRenderCallback { [weak self] in
            guard let self = self else { return }
            
            self.reloadData(msg)
        }
    }
    
    func reloadData(_ msg: ReloadMatchWidgetMessage) {
        self.sendMessage(msg)
    }
    
    override func parseMessage(_ name: MessageType, _ messageData: [String : Any]) {
        switch name {
        case .loadDanmaku:
            self.parseMessageCallBack?(name, messageData)
        default:
            super.parseMessage(name, messageData)
        }
        
    }

}
