//
//  FTPConnectViewController.swift
//  AniXPlayer
//
//  tvOS FTP 连接页面
//

import UIKit

class FTPConnectViewController: RemoteConnectViewController {

    override var addressScheme: String { "ftp://" }

    init(loginInfo: LoginInfo? = nil) {
        super.init(loginInfo: loginInfo, fileManager: FTPFileManager.shared)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
