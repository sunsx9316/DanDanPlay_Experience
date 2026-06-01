//
//  WebDavLoginHistoryViewController.swift
//  AniXPlayer
//
//  tvOS WebDAV 登录历史页面
//

import UIKit

class WebDavLoginHistoryViewController: RemoteLoginHistoryViewController {

    override var fileManager: FileManagerProtocol {
        return WebDavFileManager.shared
    }

    override var fileManagerDesc: String {
        return NSLocalizedString("WebDAV", comment: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
    }

    private func loadData() {
        self.loginInfos = Preferences.shared.webDavLoginInfos ?? []
        tableView.reloadData()
    }

    override func saveData() {
        Preferences.shared.webDavLoginInfos = loginInfos
    }

    override func rootFile(for loginInfo: LoginInfo) -> File {
        if let rootPath = loginInfo.parameter?[LoginInfo.Key.webDavRootPath.rawValue],
           !rootPath.isEmpty,
           let url = URL(string: rootPath) {
            return WebDavFile(url: url, fileSize: 0)
        }
        return WebDavFile.rootFile
    }

    override func connectViewController(loginInfo: LoginInfo?) -> RemoteConnectViewController {
        return WebDavConnectViewController(loginInfo: loginInfo)
    }
}
