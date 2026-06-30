//
//  LoginViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2025/6/29.
//

import Cocoa
import SnapKit

class LoginViewController: ViewController {

    private lazy var usernameTextField: TextField = {
        let textField = TextField()
        textField.placeholderString = NSLocalizedString("用户名", comment: "")
        return textField
    }()

    private lazy var passwordTextField: NSSecureTextField = {
        let textField = NSSecureTextField()
        textField.font = .ddp_normal
        textField.textColor = .textColor
        textField.placeholderString = NSLocalizedString("密码", comment: "")
        return textField
    }()

    private lazy var loginButton: Button = {
        let button = Button.custom()
        button.title = NSLocalizedString("登录", comment: "")
        button.target = self
        button.action = #selector(loginButtonTapped)
        button.keyEquivalent = "\r"
        let color = NSColor(named: "MainColor") ?? .systemBlue
        button.wantsLayer = true
        button.layer?.backgroundColor = color.cgColor
        button.layer?.cornerRadius = 4
        return button
    }()

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 250))
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.defaultButtonCell = loginButton.cell as? NSButtonCell
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("登录", comment: "")

        view.addSubview(usernameTextField)
        view.addSubview(passwordTextField)
        view.addSubview(loginButton)

        usernameTextField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.leading.equalToSuperview().offset(40)
            make.trailing.equalToSuperview().offset(-40)
            make.height.equalTo(28)
        }

        passwordTextField.snp.makeConstraints { make in
            make.top.equalTo(usernameTextField.snp.bottom).offset(20)
            make.leading.equalTo(usernameTextField)
            make.trailing.equalTo(usernameTextField)
            make.height.equalTo(28)
        }

        loginButton.snp.makeConstraints { make in
            make.top.equalTo(passwordTextField.snp.bottom).offset(24)
            make.leading.equalTo(passwordTextField)
            make.trailing.equalTo(passwordTextField)
            make.height.equalTo(32)
        }
    }

    @objc private func loginButtonTapped() {
        guard let userName = usernameTextField.stringValue.nilIfEmpty else {
            view.show(text: NSLocalizedString("请输入用户名", comment: ""))
            return
        }
        guard let password = passwordTextField.stringValue.nilIfEmpty else {
            view.show(text: NSLocalizedString("请输入密码", comment: ""))
            return
        }

        UserNetworkHandle.login(userName: userName, password: password) { res, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.view.show(error: error)
                } else if let res = res {
                    Preferences.shared.loginInfo = res
                    self.view.show(text: NSLocalizedString("登录成功！", comment: ""))
                    self.view.window?.close()
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        return trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
