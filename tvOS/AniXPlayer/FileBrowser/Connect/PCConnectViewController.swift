//
//  PCConnectViewController.swift
//  AniXPlayer
//
//  tvOS 电脑端连接页面
//

import UIKit

class PCConnectViewController: RemoteConnectViewController {

    override var addressScheme: String { "http://" }

    init(loginInfo: LoginInfo? = nil) {
        super.init(loginInfo: loginInfo, fileManager: PCFileManager.shared)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupFields() {
        super.setupFields()

        passwordLabel.attributedPlaceholder = NSAttributedString(
            string: fileManager.passwordDesc,
            attributes: [.foregroundColor: UIColor.lightGray]
        )
    }
}
