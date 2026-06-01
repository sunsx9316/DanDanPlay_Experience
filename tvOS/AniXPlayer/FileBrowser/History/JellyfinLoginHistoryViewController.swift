//
//  JellyfinLoginHistoryViewController.swift
//  AniXPlayer
//
//  tvOS Jellyfin 登录历史页面 — 复用 Emby API 兼容层
//

import UIKit

class JellyfinLoginHistoryViewController: RemoteLoginHistoryViewController {

    override var fileManager: FileManagerProtocol {
        return EmbyFileManager.shared
    }

    override var fileManagerDesc: String {
        return NSLocalizedString("Jellyfin", comment: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
    }

    private func loadData() {
        self.loginInfos = Preferences.shared.jellyfinLoginInfos ?? []
        tableView.reloadData()
    }

    override func saveData() {
        Preferences.shared.jellyfinLoginInfos = loginInfos
    }

    override func rootFile(for loginInfo: LoginInfo) -> File {
        return EmbyFile.rootFile
    }

    override func connectViewController(loginInfo: LoginInfo?) -> RemoteConnectViewController {
        return JellyfinConnectViewController(loginInfo: loginInfo)
    }

    override var isEmpty: Bool {
        return loginInfos.isEmpty
    }
}
