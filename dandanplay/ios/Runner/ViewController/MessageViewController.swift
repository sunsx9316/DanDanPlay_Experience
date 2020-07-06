//
//  MessageViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/24.
//

import UIKit
import DDPShare

class MessageViewController: FlutterViewController {
    
    lazy var channel: FlutterBasicMessageChannel? = {
        var channel: FlutterBasicMessageChannel?
        if let engine = self.engine {
            channel = FlutterBasicMessageChannel(name: self.channelName, binaryMessenger: engine.binaryMessenger, codec: FlutterJSONMessageCodec())
        }
        
        return channel
    }()
    
    var channelName: String {
        return "com.dandanplay.native/message"
    }
    
    private var routeName: String?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    override init(engine: FlutterEngine, nibName: String?, bundle nibBundle: Bundle?) {
        super.init(engine: engine, nibName: nibName, bundle: nibBundle)
        self.setupInit()
    }
    
    override init(project: FlutterDartProject?, nibName: String?, bundle nibBundle: Bundle?) {
        super.init(project: project, nibName: nibName, bundle: nibBundle)
        self.setupInit()
    }
    
    convenience init() {
        let delegate = UIApplication.shared.delegate as! AppDelegate
        self.init(engine: delegate.engine, nibName: nil, bundle: nil)
    }
    
    func sendMessage(_ messageData: MessageProtocol) {
        var aMessage = [String : Any]();
        aMessage["name"] = messageData.messageName
        aMessage["data"] = messageData.messageData
        self.channel?.sendMessage(aMessage)
    }
    
    func parseMessage(_ name: MessageType, _ messageData: [String : Any]) {
        
    }
    
    //MARK: Private Method
    private func setupInit() {
        self.channel?.setMessageHandler { [weak self] (obj, reply) in
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
        
        GeneratedPluginRegistrant.register(with: self)
    }
    
}
