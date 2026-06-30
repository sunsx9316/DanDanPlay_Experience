//
//  EmbyConnectSvrViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa
import SnapKit

class EmbyConnectSvrViewController: BaseConnectSvrViewController {

    private enum AuthMode: Int {
        case apiKey = 0
        case usernamePassword = 1
    }

    private lazy var modeSegment: NSSegmentedControl = {
        let segment = NSSegmentedControl(labels: [
            NSLocalizedString("API Key", comment: ""),
            NSLocalizedString("用户名+密码", comment: "")
        ], trackingMode: .selectOne, target: self, action: #selector(modeDidChange))
        segment.selectedSegment = AuthMode.apiKey.rawValue
        return segment
    }()

    private lazy var apiKeyField: TextField = {
        let tf = TextField()
        tf.placeholderString = fileManager.apiKeyDesc
        return tf
    }()

    private var currentMode: AuthMode {
        return AuthMode(rawValue: modeSegment.selectedSegment) ?? .apiKey
    }

    private let customTitle: String?

    init(loginInfo: LoginInfo?, customTitle: String? = nil) {
        self.customTitle = customTitle
        super.init(loginInfo: loginInfo, fileManager: EmbyFileManager.shared)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let customTitle = customTitle {
            self.title = customTitle
        }

        // 在 formStack 顶部插入分段选择器
        formStack.insertArrangedSubview(modeSegment, at: 0)
        modeSegment.snp.makeConstraints { make in
            make.width.equalTo(formStack).offset(-40)
            make.height.equalTo(28)
        }

        // 在 passwordField 的父视图（passwordRow）后插入 apiKeyField row
        if let passwordRow = passwordField.superview as? NSStackView,
           let passwordIndex = formStack.arrangedSubviews.firstIndex(of: passwordRow) {
            let apiRow = makeFormRow(label: fileManager.apiKeyDesc, field: apiKeyField)
            formStack.insertArrangedSubview(apiRow, at: passwordIndex + 1)
            apiRow.snp.makeConstraints { make in
                make.width.equalTo(formStack).offset(-40)
            }
        }

        // 根据已保存的登录信息判断上次使用的模式
        if let userName = loginInfo?.auth?.userName, !userName.isEmpty {
            modeSegment.selectedSegment = AuthMode.usernamePassword.rawValue
        }

        updateUIForAuthMode()

        if let info = loginInfo {
            apiKeyField.stringValue = info.auth?.apiKey ?? ""
        }
    }

    // MARK: - Override

    override func createAuth() -> Auth? {
        if currentMode == .apiKey {
            return Auth(userName: nil, password: nil, apiKey: apiKeyField.stringValue)
        }
        return Auth(userName: userNameField.stringValue, password: passwordField.stringValue)
    }

    override func update(with loginInfo: LoginInfo?) {
        super.update(with: loginInfo)
        apiKeyField.stringValue = loginInfo?.auth?.apiKey ?? ""
    }

    // MARK: - Private

    @objc private func modeDidChange() {
        if currentMode == .apiKey {
            userNameField.stringValue = ""
        }
        updateUIForAuthMode()
    }

    private func updateUIForAuthMode() {
        let isAPIKey = currentMode == .apiKey
        userNameField.superview?.isHidden = isAPIKey
        passwordField.superview?.isHidden = isAPIKey
        apiKeyField.superview?.isHidden = !isAPIKey
    }
}
