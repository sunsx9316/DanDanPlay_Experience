//
//  FTPLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/30.
//

import UIKit

class FTPLoginHistoryViewController: BaseLoginHistoryViewController<FTPFile> {
    
    override var dataSource: [LoginInfo] {
        get {
            return Preferences.shared.ftpLoginInfos ?? []
        }
        
        set {
            Preferences.shared.ftpLoginInfos = newValue
        }
    }
    
    override func jumpToConnectViewController(_ loginInfo: LoginInfo? = nil) {
        let vc = FTPConnectSvrViewController(loginInfo: loginInfo, fileManager: FTPFile.fileManager)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }

}
