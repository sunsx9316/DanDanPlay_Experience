//
//  JellyfinConnectSvrViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/31.
//

import UIKit

class JellyfinConnectSvrViewController: BaseConnectSvrViewController {

    private enum AuthMode: Int {
        case apiKey = 0
        case usernamePassword = 1
    }

    private lazy var modeSegment: UISegmentedControl = {
        let segment = UISegmentedControl(items: [
            NSLocalizedString("API Key", comment: ""),
            NSLocalizedString("用户名+密码", comment: "")
        ])
        segment.selectedSegmentIndex = AuthMode.apiKey.rawValue
        segment.addTarget(self, action: #selector(modeDidChange), for: .valueChanged)
        return segment
    }()

    private lazy var apiKeyLabel: TextField = {
        let textField = TextField()
        textField.attributedPlaceholder = .init(
            string: NSLocalizedString("API Key", comment: ""),
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        return textField
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("Jellyfin", comment: "")

        guard let stackView = self.addressLabel.superview as? UIStackView else { return }

        // 在 stackView 顶部插入分段选择器
        stackView.insertArrangedSubview(self.modeSegment, at: 0)
        self.modeSegment.snp.makeConstraints { make in
            make.height.equalTo(32)
        }

        // 在 passwordLabel 之后插入 apiKeyLabel
        if let passwordIndex = stackView.arrangedSubviews.firstIndex(of: self.passwordLabel) {
            stackView.insertArrangedSubview(self.apiKeyLabel, at: passwordIndex + 1)
        }
        self.apiKeyLabel.snp.makeConstraints { make in
            make.height.equalTo(self.addressLabel)
        }

        // 根据已保存的登录信息判断上次使用的模式
        if let userName = self.userNameLabel.text, !userName.isEmpty {
            modeSegment.selectedSegmentIndex = AuthMode.usernamePassword.rawValue
        }

        updateUIForAuthMode()

        self.addressLabel.addTarget(self, action: #selector(addressTextFieldDidBeginEditing), for: .editingDidBegin)
    }

    override func update(with loginInfo: LoginInfo?) {
        super.update(with: loginInfo)
        self.apiKeyLabel.text = loginInfo?.auth?.apiKey
    }

    override func createAuth() -> Auth? {
        if currentMode == .apiKey {
            return Auth(userName: nil, password: nil, apiKey: self.apiKeyLabel.text)
        }
        return Auth(userName: self.userNameLabel.text, password: self.passwordLabel.text)
    }

    private var currentMode: AuthMode {
        return AuthMode(rawValue: modeSegment.selectedSegmentIndex) ?? .apiKey
    }

    @objc private func modeDidChange() {
        let isAPIKey = currentMode == .apiKey
        if isAPIKey {
            self.userNameLabel.text = nil
        }
        updateUIForAuthMode()
    }

    private func updateUIForAuthMode() {
        let isAPIKey = currentMode == .apiKey
        self.userNameLabel.isHidden = isAPIKey
        self.passwordLabel.isHidden = isAPIKey
        self.apiKeyLabel.isHidden = !isAPIKey
    }

    @objc private func addressTextFieldDidBeginEditing() {
        if self.addressLabel.text?.isEmpty == true {
            self.addressLabel.text = "http://"
        }
    }
}
