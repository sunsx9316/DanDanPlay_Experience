//
//  FTPConnectSvrViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa

class FTPConnectSvrViewController: BaseConnectSvrViewController {

    init(loginInfo: LoginInfo?) {
        super.init(loginInfo: loginInfo, fileManager: FTPFileManager.shared)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
