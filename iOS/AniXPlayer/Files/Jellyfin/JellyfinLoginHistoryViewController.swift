//
//  JellyfinLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/31.
//

import UIKit

class JellyfinLoginHistoryViewController: BaseLoginHistoryViewController<EmbyFile> {

    override var dataSource: [LoginInfo] {
        get { return Preferences.shared.jellyfinLoginInfos ?? [] }
        set { Preferences.shared.jellyfinLoginInfos = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("Jellyfin", comment: "")
    }

    override func jumpToConnectViewController(_ loginInfo: LoginInfo? = nil) {
        let vc = EmbyConnectSvrViewController(loginInfo: loginInfo, customTitle: NSLocalizedString("Jellyfin", comment: ""))
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
