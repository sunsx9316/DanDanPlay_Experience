//
//  MainViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/2/16.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa
import FlutterMacOS
import SnapKit
import HandyJSON
import DDPShare
import DDPMediaPlayer

/// 主控制器，负责与flutter通信
class MainViewController: MessageViewController {
    
    private lazy var dragView: DragView = {
        let view = DragView()
        view.dragFilesCallBack = { [weak self] (urls) in
            guard let self = self else {
                return
            }
            
            let items = urls.compactMap({ LocalFile(with: $0) })
            self.loadItems(items)
        }
        return view
    }()
    
    private var playerWindowController: PlayerWindowController?
    private var playerViewController: PlayerViewController? {
        return playerWindowController?.contentViewController as? PlayerViewController
    }
    
    private lazy var HUDViewsMapper: NSMapTable<NSString, ProgressHUD> = {
        return NSMapTable<NSString, ProgressHUD>.strongToWeakObjects()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        self.view.addSubview(self.dragView)
        self.dragView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }
        
    }
    
    override func parseMessage(_ name: MessageType, _ messageData: [String : Any]){
        
        switch name {
        case .becomeKeyWindow:
            super.parseMessage(name, messageData)
        case .loadDanmaku:
            playerWindowController?.window?.makeKeyAndOrderFront(nil)
            playerViewController?.parseMessage(name, data: messageData)
        case .HUDMessage:
            guard let msg = HUDMessage.deserialize(from: messageData) else {
                return
            }
            
            let key = msg.key as NSString
            
            let cacheHUD: ProgressHUD
            
            if key.length > 0, let aCacheHUD = HUDViewsMapper.object(forKey: key) {
                cacheHUD = aCacheHUD
            } else {
                
                switch msg.style {
                case .tips:
                    cacheHUD = ProgressHUDHelper.showHUDWithText(msg.text)
                case .progress:
                    cacheHUD = ProgressHUDHelper.showProgressHUD(text: msg.text, progress: msg.progress)
                }
                
                HUDViewsMapper.setObject(cacheHUD, forKey: key)
            }
            
            if msg.isDismiss {
                cacheHUD.hide(true)
            } else {
                switch msg.style {
                case .tips:
                    break
                case .progress:
                    cacheHUD.setStatus(msg.text)
                    cacheHUD.progress = Double(msg.progress)
                }
            }
        case .appVersion:
            guard let msg = AppVersionMessage.deserialize(from: messageData),
                let delegate = NSApp.delegate as? AppDelegate else {
                return
            }

            delegate.showUpdatePopover(msg)
        default:
            playerViewController?.parseMessage(name, data: messageData)
        }
    }
    
    //MARK: Private
    private func loadItems(_ items: [File]) {
        if let vc = self.playerViewController {
            vc.loadItem(items)
            playerWindowController?.window?.makeKeyAndOrderFront(nil)
        } else {
            let playerWindowController = PlayerWindowController(items: items)
            self.playerWindowController = playerWindowController
            playerWindowController.closeCallBack = { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.playerWindowController = nil
            }
            playerWindowController.showWindow(nil)
        }
    }
    
}
