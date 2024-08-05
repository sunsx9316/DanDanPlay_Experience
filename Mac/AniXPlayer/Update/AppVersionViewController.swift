//
//  AppVersionViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/26.
//

import Cocoa

class AppVersionViewController: ViewController {
    
    @IBOutlet weak var label: NSTextField!
    
    @IBOutlet weak var updateButton: NSButton!
    
    private(set) var appVersion: UpdateInfo!
    
    private lazy var appVersionModel = AppVersionModel()
    
    var onClickCancelCallBack: ((AppVersionViewController) -> Void)?
    
    var onClickOKCallBack: ((AppVersionViewController) -> Void)?
    
    init(appVersiotn: UpdateInfo) {
        super.init()
        self.appVersion = appVersiotn
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let version = appVersion?.shortVersion {
            self.title = "有新版本 \(version) 更新"
        } else {
            self.title = "有新版本更新"
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
        appVersionModel.updateIgnoreVersion(updateInfo: appVersion)
        onClickOKCallBack?(self)
    }
    
    
    @IBAction func onClickCancelButton(_ sender: NSButton) {
        appVersionModel.updateIgnoreVersion(updateInfo: appVersion)
        onClickCancelCallBack?(self)
    }
}
