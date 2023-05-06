//
//  PCLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/2.
//

import UIKit

class PCLoginHistoryViewController: BaseLoginHistoryViewController<PCFile> {

    override var dataSource: [LoginInfo] {
        get {
            return Preferences.shared.pcLoginInfos ?? []
        }
        
        set {
            Preferences.shared.pcLoginInfos = newValue
        }
    }
    
    override func jumpToConnectViewController(_ loginInfo: LoginInfo? = nil) {
        let vc = PCConnectSvrViewController(loginInfo: loginInfo, fileManager: PCFileManager.shared)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }

}
