//
//  SMBConnectViewController.swift
//  AniXPlayer
//
//  tvOS SMB 连接页面
//

import UIKit

class SMBConnectViewController: RemoteConnectViewController {

    private enum AuthMode: Int {
        case guest
        case registered
    }

    private var authMode: AuthMode = .guest {
        didSet {
            updateAuthModeUI()
        }
    }

    private lazy var segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: [
            NSLocalizedString("客人", comment: ""),
            NSLocalizedString("注册用户", comment: "")
        ])
        sc.selectedSegmentIndex = 0
        sc.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        return sc
    }()

    override var addressScheme: String { "smb://" }

    init(loginInfo: LoginInfo? = nil) {
        super.init(loginInfo: loginInfo, fileManager: SMBFileManager.shared)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupFields() {
        stackView.insertArrangedSubview(segmentedControl, at: 0)
        segmentedControl.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        super.setupFields()

        // 恢复模式
        if let info = loginInfo, let userName = info.auth?.userName, userName != "guest" {
            authMode = .registered
            segmentedControl.selectedSegmentIndex = 1
        } else {
            authMode = .guest
        }
    }

    @objc private func segmentChanged() {
        authMode = AuthMode(rawValue: segmentedControl.selectedSegmentIndex) ?? .guest
    }

    private func updateAuthModeUI() {
        switch authMode {
        case .guest:
            userNameLabel.text = "guest"
            userNameLabel.isHidden = true
            passwordLabel.isHidden = true
        case .registered:
            userNameLabel.text = loginInfo?.auth?.userName
            userNameLabel.isHidden = false
            passwordLabel.isHidden = false
        }
    }

    override func loginParameter() -> [String: String]? {
        return nil
    }

    override func onTouchLoginButton() {
        // 客人模式自动设置 "guest" 用户名
        if authMode == .guest {
            userNameLabel.text = "guest"
            passwordLabel.text = nil
        }
        super.onTouchLoginButton()
    }
}
