//
//  FTPLoginHistoryViewController.swift
//  AniXPlayer
//
//  tvOS FTP 登录历史页面
//

import UIKit

class FTPLoginHistoryViewController: RemoteLoginHistoryViewController {

    override var fileManagerDesc: String {
        return NSLocalizedString("FTP", comment: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
    }

    private func loadData() {
        self.loginInfos = Preferences.shared.ftpLoginInfos ?? []
        tableView.reloadData()
    }

    override func saveData() {
        Preferences.shared.ftpLoginInfos = loginInfos
    }

    override func rootFile(for loginInfo: LoginInfo) -> File {
        return FTPFile.rootFile
    }

    override func connectViewController(loginInfo: LoginInfo?) -> RemoteConnectViewController {
        return FTPConnectViewController(loginInfo: loginInfo)
    }
}
