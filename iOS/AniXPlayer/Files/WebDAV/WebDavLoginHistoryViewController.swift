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

    override func displayAddress(for loginInfo: LoginInfo) -> String? {
        guard let rootPath = loginInfo.parameter?[LoginInfo.Key.webDavRootPath.rawValue], !rootPath.isEmpty else {
            return loginInfo.url.absoluteString
        }
        var url = loginInfo.url
        url.appendPathComponent(rootPath)
        return url.absoluteString
    }

    override func rootFile(for loginInfo: LoginInfo) -> any File {
        if let rootPath = loginInfo.parameter?[LoginInfo.Key.webDavRootPath.rawValue],
           !rootPath.isEmpty,
           let url = URL(string: rootPath) {
            return WebDavFile(url: url, fileSize: 0)
        }
        return WebDavFile.rootFile
    }
    
    override func viewControllerDidSuccessConnected(_ viewController: ViewController, loginInfo: LoginInfo) {
        self.rootPath = loginInfo.parameter?[LoginInfo.Key.webDavRootPath.rawValue]
        super.viewControllerDidSuccessConnected(viewController, loginInfo: loginInfo)
    }
}
