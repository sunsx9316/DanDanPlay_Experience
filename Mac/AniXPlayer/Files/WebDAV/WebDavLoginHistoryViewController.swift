//
//  WebDavLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa

class WebDavLoginHistoryViewController: BaseLoginHistoryViewController<WebDavFile> {

    override var dataSource: [LoginInfo] {
        get { return Preferences.shared.webDavLoginInfos ?? [] }
        set { Preferences.shared.webDavLoginInfos = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = WebDavFile.fileManager.desc
    }
}
