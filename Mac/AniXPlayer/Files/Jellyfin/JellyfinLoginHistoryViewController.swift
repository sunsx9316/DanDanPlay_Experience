//
//  JellyfinLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa

class JellyfinLoginHistoryViewController: BaseLoginHistoryViewController<EmbyFile> {

    override var dataSource: [LoginInfo] {
        get { return Preferences.shared.jellyfinLoginInfos ?? [] }
        set { Preferences.shared.jellyfinLoginInfos = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Jellyfin"
    }

    override func jumpToConnectViewController(_ loginInfo: LoginInfo? = nil) {
        let vc = EmbyConnectSvrViewController(loginInfo: loginInfo, customTitle: NSLocalizedString("Jellyfin", comment: ""))
        vc.navigator = navigator
        vc.onSuccessConnected = { [weak self] loginInfo in
            guard let self = self else { return }
            var loginInfos = self.dataSource
            if let index = loginInfos.firstIndex(where: { $0 == loginInfo }) {
                loginInfos[index] = loginInfo
            } else {
                loginInfos.append(loginInfo)
            }
            self.dataSource = loginInfos
            self.tableView.reloadData()

            let browser = FileBrowserViewController(rootFile: EmbyFile.rootFile, selectedFile: nil, filterType: .video)
            browser.navigator = self.navigator
            browser.onSelectFile = self.onSelectFile
            self.navigator?.pushViewController(browser)
        }
        navigator?.pushViewController(vc)
    }
}
