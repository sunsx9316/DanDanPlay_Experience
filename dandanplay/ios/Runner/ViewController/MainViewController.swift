//
//  MainViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/16.
//

import UIKit
import DDPShare

class MainViewController: MessageViewController {
    
    private weak var playerNavigationController: PlayerNavigationController?

    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    

    override func parseMessage(_ name: MessageType, _ messageData: [String : Any]) {
        switch name {
        case .loadFiles:
            guard let msg = LoadFilesMessage.deserialize(from: messageData) else { return }
            let urls = msg.paths.compactMap({ URL(fileURLWithPath: $0) })
            
            if let playerNavigationController = self.playerNavigationController {
                playerNavigationController.playerViewController?.loadURLs(urls)
            } else {
                let nav = PlayerNavigationController(urls: urls)
                self.playerNavigationController = nav
                self.present(nav, animated: true, completion: nil)
            }
            
            break
        default:
            self.playerNavigationController?.playerViewController?.parseMessage(name, data: messageData)
            break
        }
    }

}
