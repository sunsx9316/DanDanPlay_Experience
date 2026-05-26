//
//  PCLoginHistoryViewController.swift
//  AniXPlayer
//
//  tvOS 电脑端登录历史页面
//

import UIKit

class PCLoginHistoryViewController: RemoteLoginHistoryViewController {

    override var fileManagerDesc: String {
        return NSLocalizedString("电脑端", comment: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
    }

    private func loadData() {
        self.loginInfos = Preferences.shared.pcLoginInfos ?? []
        tableView.reloadData()
    }

    override func saveData() {
        Preferences.shared.pcLoginInfos = loginInfos
    }

    override func rootFile(for loginInfo: LoginInfo) -> File {
        return PCFile.rootFile
    }

    override func connectViewController(loginInfo: LoginInfo?) -> RemoteConnectViewController {
        return PCConnectViewController(loginInfo: loginInfo)
    }
}
