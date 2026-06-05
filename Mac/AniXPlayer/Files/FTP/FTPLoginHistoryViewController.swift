//
//  FTPLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa

class FTPLoginHistoryViewController: BaseLoginHistoryViewController<FTPFile> {

    override var dataSource: [LoginInfo] {
        get { return Preferences.shared.ftpLoginInfos ?? [] }
        set { Preferences.shared.ftpLoginInfos = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = FTPFile.fileManager.desc
    }
}
