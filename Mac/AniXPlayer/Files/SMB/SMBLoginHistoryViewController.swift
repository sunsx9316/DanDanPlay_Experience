//
//  SMBLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa

class SMBLoginHistoryViewController: BaseLoginHistoryViewController<SMBFile> {

    override var dataSource: [LoginInfo] {
        get { return Preferences.shared.smbLoginInfos ?? [] }
        set { Preferences.shared.smbLoginInfos = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = SMBFile.fileManager.desc
    }
}
