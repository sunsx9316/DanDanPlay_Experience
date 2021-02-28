//
//  MessageViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/3/5.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa
import FlutterMacOS
import DDPShare

class MessageViewController: OCMessageViewController {
    
    lazy var channel: FlutterBasicMessageChannel = {
        let channel = FlutterBasicMessageChannel(name: self.channelName, binaryMessenger: self.engine.binaryMessenger, codec: FlutterJSONMessageCodec());
        
        return channel
    }()
    
    private lazy var navigationChannel: FlutterMethodChannel = {
        return FlutterMethodChannel(name: "flutter/navigation", binaryMessenger: self.engine.binaryMessenger, codec: FlutterJSONMethodCodec())
    }()
    
    var channelName: String {
        return "com.dandanplay.native/message"
    }
    
    private var routeName: String?
    
    required init(coder nibNameOrNil: NSCoder) {
        super.init(coder: nibNameOrNil)
        
        self.setupInit()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.setupInit()
    }
    
    override init(project: FlutterDartProject?) {
        super.init(project: project)
        self.setupInit()
    }
    
    init(routeName: String) {
        super.init(project: nil)
        self.routeName = routeName
        self.setupInit()
    }
    
    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }
    
    func sendMessage(_ messageData: MessageProtocol) {
        var aMessage = [String : Any]();
        aMessage["name"] = messageData.messageName
        aMessage["data"] = messageData.messageData
        self.channel.sendMessage(aMessage)
    }
    
    func parseMessage(_ name: MessageType, _ messageData: [String : Any]) {
        if name == .becomeKeyWindow {
            self.view.window?.makeKeyAndOrderFront(self)
        }
    }
    
    func push(_ routeName: String) {
        self.navigationChannel.invokeMethod("pushRoute", arguments: routeName)
    }
    
    func popRoute() {
        self.navigationChannel.invokeMethod("popRoute", arguments: nil)
    }
    
    override func engineDidLaunch() {
        if let routeName = self.routeName {
            let msg = SetInitialRouteMessage()
            msg.routeName = routeName
            self.sendMessage(msg)
        }
    }
    
    //MARK: Private Method
    private func setupInit() {
        self.channel.setMessageHandler { [weak self] (obj, reply) in
            guard let self = self else {
                reply(false)
                return
            }
            
            if let obj = obj as? [String : Any] {
                
                guard let name = obj["name"] as? String,
                    let enumValue = MessageType(rawValue: name) else { return }
                let data = obj["data"] as? [String : Any] ?? [:]
                
                DispatchQueue.main.async {
                    self.parseMessage(enumValue, data)
                    reply(true)
                }
            } else {
                reply(false)
            }
        }
        
        RegisterGeneratedPlugins(registry: self)
        
        DandanplayfilepickerPlugin.register(with: self.registrar(forPlugin: "DandanplayfilepickerPlugin"))
        SwiftDandanplaystorePlugin.register(with: self.registrar(forPlugin: "SwiftDandanplaystorePlugin"))
    }
    
}
