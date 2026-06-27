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

    private lazy var pathLabel: UITextField = {
        let tf = UITextField()
        tf.font = .ddp_normal()
        tf.textColor = .label
        tf.attributedPlaceholder = NSAttributedString(
            string: NSLocalizedString("可选子路径，如 video/", comment: ""),
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        return tf
    }()

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

        // 在备注之前插入路径输入框
        stackView.insertArrangedSubview(pathLabel, at: stackView.arrangedSubviews.count - 2)
        pathLabel.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        // 恢复已保存的子路径
        if let subPath = loginInfo?.parameter?[LoginInfo.Key.smbSubPath.rawValue], !subPath.isEmpty {
            pathLabel.text = subPath
        }

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
        let path = pathLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : [LoginInfo.Key.smbSubPath.rawValue: path]
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
