//
//  LoginViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2025/6/29.
//

import Cocoa
import SnapKit

class LoginViewController: ViewController {

    private static let fieldHeight: CGFloat = 32
    private static let horizontalPadding: CGFloat = 40

    private lazy var usernameTextField: TextField = {
        let tf = TextField()
        tf.centersVertically = true
        tf.placeholderString = NSLocalizedString("用户名", comment: "")
        tf.isBordered = false
        tf.wantsLayer = true
        tf.layer?.cornerRadius = 6
        tf.layer?.borderWidth = 1
        tf.layer?.borderColor = NSColor.separatorColor.cgColor
        tf.backgroundColor = NSColor.textBackgroundColor
        return tf
    }()

    private lazy var passwordTextField: SecureTextField = {
        let tf = SecureTextField()
        tf.centersVertically = true
        tf.placeholderString = NSLocalizedString("密码", comment: "")
        tf.isBordered = false
        tf.wantsLayer = true
        tf.layer?.cornerRadius = 6
        tf.layer?.borderWidth = 1
        tf.layer?.borderColor = NSColor.separatorColor.cgColor
        tf.backgroundColor = NSColor.textBackgroundColor
        return tf
    }()

    private lazy var loginButton: Button = {
        let button = Button.custom()
        let title = NSLocalizedString("登录", comment: "")
        let attrTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.ddp_normal(weight: .medium) as Any,
                .foregroundColor: NSColor.white,
            ]
        )
        button.attributedTitle = attrTitle
        button.addTarget(self, action: #selector(loginButtonTapped))
        button.keyEquivalent = "\r"
        button.wantsLayer = true
        button.layer?.backgroundColor = (NSColor(named: "MainColor") ?? .systemBlue).cgColor
        button.layer?.cornerRadius = 6
        return button
    }()

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 260))
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
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.height.equalTo(Self.fieldHeight)
        }

        passwordTextField.snp.makeConstraints { make in
            make.top.equalTo(usernameTextField.snp.bottom).offset(16)
            make.leading.equalTo(usernameTextField)
            make.trailing.equalTo(usernameTextField)
            make.height.equalTo(Self.fieldHeight)
        }

        loginButton.snp.makeConstraints { make in
            make.top.equalTo(passwordTextField.snp.bottom).offset(24)
            make.leading.equalTo(passwordTextField)
            make.trailing.equalTo(passwordTextField)
            make.height.equalTo(36)
        }
    }

    @objc private func loginButtonTapped() {
        guard let userName = usernameTextField.text, !userName.isEmpty else {
            view.show(text: NSLocalizedString("请输入用户名", comment: ""))
            return
        }
        guard let password = passwordTextField.text, !password.isEmpty else {
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
