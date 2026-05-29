//
//  EmbyLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/29.
//

import UIKit

class EmbyLoginHistoryViewController: BaseLoginHistoryViewController<EmbyFile> {

    override var dataSource: [LoginInfo] {
        get { return Preferences.shared.embyLoginInfos ?? [] }
        set { Preferences.shared.embyLoginInfos = newValue }
    }

    override func jumpToConnectViewController(_ loginInfo: LoginInfo? = nil) {
        let vc = EmbyConnectSvrViewController(loginInfo: loginInfo, fileManager: EmbyFileManager.shared)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
