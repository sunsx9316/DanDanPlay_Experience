//
//  MainViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/16.
//

import UIKit
import DDPShare
import MBProgressHUD

class MainViewController: MessageViewController {
    
    private weak var playerNavigationController: PlayerNavigationController?
    private lazy var HUDViewsMapper: NSMapTable<NSString, MBProgressHUD> = {
        return NSMapTable<NSString, MBProgressHUD>.strongToWeakObjects()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.isPad ? .all : .portrait
    }
    
    override var shouldAutorotate: Bool {
        return UIDevice.current.isPad
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    override func parseMessage(_ name: MessageType, _ messageData: [String : Any]) {
        switch name {
        case .loadFiles:
            guard let msg = LoadFilesMessage.deserialize(from: messageData) else { return }
            
            let urls = msg.fileDatas.compactMap { (model) -> URL? in
                if let urlDataString = model.urlDataString, let data = Data(base64Encoded: urlDataString) {
                    var isStale = false
                    return try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                }
                return nil
            }
            
            if let playerNavigationController = self.playerNavigationController {
                playerNavigationController.playerViewController?.loadURLs(urls)
            } else {
                let nav = PlayerNavigationController(urls: urls)
                self.playerNavigationController = nav
                self.present(nav, animated: true, completion: nil)
            }
            
            break
        case .HUDMessage:
            guard let msg = HUDMessage.deserialize(from: messageData) else { return }
            
            let key = msg.key as NSString
            
            let cacheHUD: MBProgressHUD
            
            if key.length > 0, let aCacheHUD = HUDViewsMapper.object(forKey: key) {
                cacheHUD = aCacheHUD
            } else {
                
                let hudSuperView: UIView
                
                if let keyWindow = UIApplication.shared.keyWindow {
                    hudSuperView = keyWindow
                } else {
                    hudSuperView = self.view
                }
                
                switch msg.style {
                case .tips:
                    cacheHUD = hudSuperView.showHUD(msg.text)
                case .progress:
                    cacheHUD = hudSuperView.showProgress()
                    cacheHUD.label.text = msg.text
                }
                
                HUDViewsMapper.setObject(cacheHUD, forKey: key)
            }
            
            if msg.isDismiss {
                cacheHUD.hide(animated: true)
            } else {
                switch msg.style {
                case .tips:
                    break
                case .progress:
                    cacheHUD.label.text = msg.text
                    cacheHUD.progress = Float(msg.progress)
                }
                HUDViewsMapper.setObject(cacheHUD, forKey: key)
            }
        default:
            self.playerNavigationController?.playerViewController?.parseMessage(name, data: messageData)
            break
        }
    }
    
}
