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


/// 主控制器，负责与flutter通信
class MainViewController: MessageViewController {
    
    private lazy var dragView: DragView = {
        let view = DragView()
        view.dragFilesCallBack = { [weak self] (paths) in
            guard let self = self else {
                return
            }
            
            self.loadFiles(paths)
        }
        return view
    }()
    
    private var playerWindowController: PlayerWindowController?
    private var playerViewController: PlayerViewController? {
        return playerWindowController?.contentViewController as? PlayerViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        self.view.addSubview(self.dragView)
        self.dragView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }
        
    }
    
    override func parseMessage(_ messageData: [String : Any]) {
        guard let name = messageData["name"] as? String,
            let enumValue = MessageType(rawValue: name) else { return }
        
        let data = messageData["data"] as? [String : Any]
        
        switch enumValue {
        case .loadDanmaku:
            playerWindowController?.window?.makeKeyAndOrderFront(nil)
            playerViewController?.parseMessage(enumValue, data: data)
        default:
            playerViewController?.parseMessage(enumValue, data: data)
        }
    }
    
    //MARK: Private
    private func loadFiles(_ files: [String]) {
        
        let urls = files.compactMap { (path) -> URL in
            return URL(fileURLWithPath: path)
        }
        
        if let vc = self.playerViewController {
            vc.loadURLs(urls)
            playerWindowController?.window?.makeKeyAndOrderFront(nil)
        } else {
            playerWindowController = PlayerWindowController(urls: urls)
            playerWindowController?.closeCallBack = { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.playerWindowController = nil
            }
            playerWindowController?.showWindow(nil)
            //            if let delegate = NSApp.delegate as? FlutterAppDelegate,
            //                let window = delegate.mainFlutterWindow,
            //                let playerWindow = playerWindowController?.window {
            //                window.addChildWindow(playerWindow, ordered: .above)
            //            }
        }
    }
    
}


extension MainViewController {
    private class DragView: NSView {
        
        var dragFilesCallBack: (([String]) -> Void)?
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setupInit()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupInit()
        }
        
        override var acceptsFirstResponder: Bool {
            return true
        }
        
        override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
            return .copy
        }
        
        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            var paths = [String]();
            sender.enumerateDraggingItems(options: [], for: nil, classes: [NSURL.self], searchOptions: [.urlReadingFileURLsOnly : true]) { (draggingItem, index, stop) in
                if let url = draggingItem.item as? NSURL, let path = url.path {
                    paths.append(path)
                }
            }
            
            if !paths.isEmpty {
                dragFilesCallBack?(paths)
            }
            
            return true
        }
        
        //MARK: Private
        private func setupInit() {
            if #available(OSX 10.13, *) {
                registerForDraggedTypes([.fileURL])
            } else {
                registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: kUTTypeFileURL as String)])
            }
        }
    }
    
}
