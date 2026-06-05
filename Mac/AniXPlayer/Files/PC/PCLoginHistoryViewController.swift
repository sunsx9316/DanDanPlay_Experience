//
//  PCLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa

class PCLoginHistoryViewController: BaseLoginHistoryViewController<PCFile> {

    override var dataSource: [LoginInfo] {
        get { return Preferences.shared.pcLoginInfos ?? [] }
        set { Preferences.shared.pcLoginInfos = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = PCFile.fileManager.desc
    }
}
