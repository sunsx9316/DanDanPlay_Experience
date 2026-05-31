//
//  EmbyLoginHistoryViewController.swift
//  AniXPlayer
//
//  tvOS Emby 登录历史页面
//

import UIKit

class EmbyLoginHistoryViewController: RemoteLoginHistoryViewController {

    override var fileManagerDesc: String {
        return NSLocalizedString("Emby", comment: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
    }

    private func loadData() {
        self.loginInfos = Preferences.shared.embyLoginInfos ?? []
        tableView.reloadData()
    }

    override func saveData() {
        Preferences.shared.embyLoginInfos = loginInfos
    }

    override func rootFile(for loginInfo: LoginInfo) -> File {
        return EmbyFile.rootFile
    }

    override func connectViewController(loginInfo: LoginInfo?) -> RemoteConnectViewController {
        return EmbyConnectViewController(loginInfo: loginInfo)
    }

    override var isEmpty: Bool {
        return loginInfos.isEmpty
    }
}
