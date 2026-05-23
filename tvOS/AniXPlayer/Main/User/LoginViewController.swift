//
//  LoginViewController.swift
//  AniXPlayer
//
//  tvOS 登录页面
//

import UIKit
import SnapKit

class LoginViewController: ViewController {

    var didLoginCallBack: ((LoginViewController, AnixLoginInfo) -> Void)?

    private lazy var usernameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = NSLocalizedString("用户名", comment: "")
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 22)
        return tf
    }()

    private lazy var passwordTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = NSLocalizedString("密码", comment: "")
        tf.borderStyle = .roundedRect
        tf.isSecureTextEntry = true
        tf.font = .systemFont(ofSize: 22)
        return tf
    }()

    private lazy var loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("登录", comment: ""), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.black, for: .focused)
        button.addTarget(self, action: #selector(loginTapped), for: .primaryActionTriggered)
        return button
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("登录", comment: "")
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defaultFocusView = usernameTextField
    }

    private func setupUI() {
        view.addSubview(usernameTextField)
        view.addSubview(passwordTextField)
        view.addSubview(loginButton)
        view.addSubview(activityIndicator)

        let fieldWidth: CGFloat = 400

        usernameTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(100)
            make.width.equalTo(fieldWidth)
            make.height.equalTo(50)
        }

        passwordTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(usernameTextField.snp.bottom).offset(30)
            make.width.equalTo(fieldWidth)
            make.height.equalTo(50)
        }

        loginButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(passwordTextField.snp.bottom).offset(40)
            make.width.equalTo(fieldWidth)
            make.height.equalTo(50)
        }

        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(loginButton.snp.bottom).offset(30)
        }
    }

    @objc private func loginTapped() {
        guard let userName = usernameTextField.text, !userName.isEmpty else {
            showAlert(NSLocalizedString("请输入用户名", comment: ""))
            return
        }

        guard let password = passwordTextField.text, !password.isEmpty else {
            showAlert(NSLocalizedString("请输入密码", comment: ""))
            return
        }

        activityIndicator.startAnimating()
        loginButton.isEnabled = false

        UserNetworkHandle.login(userName: userName, password: password) { [weak self] loginInfo, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.loginButton.isEnabled = true

                if let error = error {
                    let alert = UIAlertController(
                        title: NSLocalizedString("错误", comment: ""),
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
                    self.present(alert, animated: true)
                } else if let loginInfo = loginInfo {
                    Preferences.shared.loginInfo = loginInfo
                    self.didLoginCallBack?(self, loginInfo)
                }
            }
        }
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
        present(alert, animated: true)
    }
}
