//
//  AppVersionViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/3/29.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa
import DDPShare

class AppVersionViewController: NSViewController {
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var updateButton: NSButton!
    @IBOutlet weak var titleLabel: NSTextField!
    
    private(set) var appVersion: AppVersionMessage?
    
    var onClickCancelCallBack: ((AppVersionViewController) -> Void)?
    
    init(appVersiotn: AppVersionMessage) {
        super.init(nibName: "AppVersionViewController", bundle: nil)
        self.appVersion = appVersiotn
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let version = appVersion?.shortVersion {
            titleLabel.stringValue = "有新版本 \(version) 更新"
        } else {
            titleLabel.stringValue = "有新版本更新"
        }
        
        if let desc = appVersion?.desc {
            label.stringValue = "更新内容：\n\n \(desc)"
        } else {
            label.stringValue = "暂无版本信息"
        }
        
    }
    
    @IBAction func onClickUpdateButton(_ sender: NSButton) {
        if let path = appVersion?.url, let url = URL(string: path) {
            NSWorkspace.shared.open(url)
        }
    }
    
    
    @IBAction func onClickCancelButton(_ sender: NSButton) {
        onClickCancelCallBack?(self)
    }
}
