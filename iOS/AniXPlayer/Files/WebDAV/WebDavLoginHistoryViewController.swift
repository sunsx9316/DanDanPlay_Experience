//
//  WebDavLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/30.
//

import UIKit

class WebDavLoginHistoryViewController: BaseLoginHistoryViewController<WebDavFile> {

    override var dataSource: [LoginInfo] {
        get {
            return Preferences.shared.webDavLoginInfos ?? []
        }
        
        set {
            Preferences.shared.webDavLoginInfos = newValue
        }
    }
    
    override func jumpToConnectViewController(_ loginInfo: LoginInfo? = nil) {
        let vc = WebDavConnectSvrViewController(loginInfo: loginInfo, fileManager: WebDavFileManager.shared)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private var rootPath: String?
    
    override var rootFile: any File {
        return WebDavFile(url: URL(string: self.rootPath ?? WebDavFile.rootFile.url.absoluteString)!, fileSize: 0)
    }
    
    override func viewControllerDidSuccessConnected(_ viewController: ViewController, loginInfo: LoginInfo) {
        self.rootPath = loginInfo.parameter?[LoginInfo.Key.webDavRootPath.rawValue]
        super.viewControllerDidSuccessConnected(viewController, loginInfo: loginInfo)
    }
}
