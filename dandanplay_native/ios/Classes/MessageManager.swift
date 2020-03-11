//
//  MessageManager.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/3.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import UIKit
import MBProgressHUD

class MessageManager {
    static let shared = MessageManager()
    
    private var rootVC: UIViewController? {
        if let window = UIApplication.shared.delegate?.window, let vc = window?.rootViewController {
            return vc
        }
        return nil
    }
    
    private lazy var hudStore: NSMapTable<NSString, MBProgressHUD> = {
        return NSMapTable<NSString, MBProgressHUD>.strongToWeakObjects()
    }()
    
    func parseMessage(_ messageData: [String : Any]) {
        
        guard let name = messageData["name"] as? String else { return }
        
        func getMessage<T>() -> T? {
            return MessageContainer<T>.deserialize(from: messageData)?.message
        }
        
        
        if name == "StartPlayMessage", let message: StartPlayMessage = getMessage() {
            parseStartPlayMessage(message)
        } else if name == "HUDMessage", let message: HUDMessage = getMessage() {
            parseHUDMessage(message)
        }
    }
    
    //MARK: Private
    
    private func parseStartPlayMessage(_ message: StartPlayMessage) {
        let playerVC = PlayerNavigationController(mediaItem: message)
        rootVC?.present(playerVC, animated: true, completion: nil)
    }
    
    private func parseHUDMessage(_ message: HUDMessage) {
        
        guard let view = rootVC?.view else {
            return
        }
        
        func defaultHUD(view: UIView) -> MBProgressHUD {
            let hud = MBProgressHUD.showAdded(to: view, animated: true)
            hud.removeFromSuperViewOnHide = true
            hud.contentColor = .white
            hud.bezelView.style = .solidColor
            hud.bezelView.color = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
            if !message.key.isEmpty {
                hudStore.setObject(hud, forKey: message.key as NSString)
            }
            return hud
        }
        
        MBProgressHUD.hide(for: view, animated: true)
        
        if message.isDismiss && !message.key.isEmpty,
            let aHUD = hudStore.object(forKey: message.key as NSString) {
            aHUD.hide(animated: true)
            return
        }
        
        switch message.style {
        case .tips:
            let hud = defaultHUD(view: view)
            hud.mode = .text
            hud.label.text = message.text
            hud.label.numberOfLines = 0
            hud.hide(animated: true, afterDelay: 1.3)
        case .progress:
            let hud = defaultHUD(view: view)
            hud.mode = .annularDeterminate
            hud.label.text = message.text
            hud.progress = message.progress
            hud.label.numberOfLines = 0
        }
    }
    
    
    
    
}

