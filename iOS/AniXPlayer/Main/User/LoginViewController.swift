//
//  LoginViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/13.
//

import UIKit
import SnapKit

class LoginViewController: ViewController {
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var usernameTextField: UITextField = {
        let textField = TextField()
        textField.placeholder = NSLocalizedString("用户名", comment: "Placeholder for username")
        textField.borderStyle = .roundedRect
        return textField
    }()
    
    private lazy var passwordTextField: UITextField = {
        let textField = TextField()
        textField.placeholder = NSLocalizedString("密码", comment: "Placeholder for password")
        textField.borderStyle = .roundedRect
        textField.isSecureTextEntry = true
        return textField
    }()
    
    private lazy var loginButton: UIButton = {
        let button = Button(type: .custom)
        button.backgroundColor = .mainColor
        button.setTitle(NSLocalizedString("登录", comment: "Title for login button"), for: .normal)
        button.setBackgroundImage(UIImage(color: .mainColor), for: .normal)
        button.setBackgroundImage(UIImage(color: .mainColor.withAlphaComponent(0.6)), for: .normal)
        button.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        button.layer.cornerRadius = 4
        button.layer.masksToBounds = true
        return button
    }()
    
    var didLoginCallBack: ((LoginViewController, AnixLoginInfo) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        
        self.title = NSLocalizedString("登录", comment: "")
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(usernameTextField)
        contentView.addSubview(passwordTextField)
        contentView.addSubview(loginButton)
        
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView)
            make.width.equalTo(scrollView)
        }
        
        usernameTextField.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(100)
            make.left.equalTo(contentView).offset(20)
            make.right.equalTo(contentView).offset(-20)
            make.height.equalTo(44)
        }
        
        passwordTextField.snp.makeConstraints { make in
            make.top.equalTo(usernameTextField.snp.bottom).offset(20)
            make.left.equalTo(usernameTextField)
            make.right.equalTo(usernameTextField)
            make.height.equalTo(44)
        }
        
        loginButton.snp.makeConstraints { make in
            make.top.equalTo(passwordTextField.snp.bottom).offset(20)
            make.left.equalTo(passwordTextField)
            make.right.equalTo(passwordTextField)
            make.height.equalTo(44)
            make.bottom.equalToSuperview()
        }
    }
    
    @objc private func loginButtonTapped() {
        
        guard let userName = usernameTextField.text, !userName.isEmpty else {
            self.view.showHUD(NSLocalizedString("请输入用户名", comment: ""))
            return
        }
        
        guard let password = passwordTextField.text, !password.isEmpty else {
            self.view.showHUD(NSLocalizedString("请输入密码", comment: ""))
            return
        }
        
        UserNetworkHandle.login(userName: userName, password: password) { res, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.view.showError(error)
                } else if let res = res {
                    self.didLoginCallBack?(self, res)
                }
            }
        }
    }
}
