//
//  BaseConnectSvrViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/6.
//

import UIKit

protocol BaseConnectSvrViewControllerDelegate: AnyObject {
    func viewControllerDidSuccessConnected(_ viewController: ViewController, loginInfo: LoginInfo)
}

class BaseConnectSvrViewController: ViewController {
    
    private lazy var addressLabel: TextField = {
        let textField = TextField()
        return textField
    }()
    
    private lazy var userNameLabel: TextField = {
        let textField = TextField()
        textField.attributedPlaceholder = .init(string: NSLocalizedString("登录用户名", comment: ""),
                                                attributes: [.foregroundColor : UIColor.lightGray])
        return textField
    }()
    
    private lazy var passwordLabel: TextField = {
        let textField = TextField()
        textField.attributedPlaceholder = .init(string: NSLocalizedString("登录密码", comment: ""),
                                                attributes: [.foregroundColor : UIColor.lightGray])
        textField.isSecureTextEntry = true
        return textField
    }()
    
    private lazy var loginButton: Button = {
        let button = Button()
        button.setTitle(NSLocalizedString("登录", comment: ""), for: .normal)
        button.backgroundColor = .mainColor
        button.layer.cornerRadius = 4
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(onTouchLoginButton), for: .touchUpInside)
        return button
    }()
    
    weak var delegate: BaseConnectSvrViewControllerDelegate?
    
    private var loginInfo: LoginInfo? {
        didSet {
            self.update(with: self.loginInfo)
        }
    }
    
    private let fileManager: FileManagerProtocol
    
    init(loginInfo: LoginInfo?, fileManager: FileManagerProtocol) {
        self.loginInfo = loginInfo
        self.fileManager = fileManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("登录", comment: "")

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 15
        stackView.addArrangedSubview(self.addressLabel)
        
        if self.fileManager.isRequiredUserName {
            stackView.addArrangedSubview(self.userNameLabel)
        }
        
        stackView.addArrangedSubview(self.passwordLabel)
        stackView.addArrangedSubview(self.loginButton)
        self.view.addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(10)
            make.leading.equalTo(10)
            make.trailing.equalTo(-10)
        }
        
        self.addressLabel.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        
        if self.fileManager.isRequiredUserName {
            self.userNameLabel.snp.makeConstraints { make in
                make.height.equalTo(self.addressLabel)
            }
        }
        
        self.passwordLabel.snp.makeConstraints { make in
            make.height.equalTo(self.addressLabel)
        }
        
        self.loginButton.snp.makeConstraints { make in
            make.height.equalTo(self.addressLabel)
        }
        
        let addressPlaceholder = self.fileManager.addressExampleDesc
        self.addressLabel.attributedPlaceholder = .init(string: addressPlaceholder,
                                                     attributes: [.foregroundColor : UIColor.lightGray])
        
        let passwordPlaceholder = self.fileManager.passwordDesc
        self.passwordLabel.attributedPlaceholder = .init(string: passwordPlaceholder,
                                                         attributes: [.foregroundColor : UIColor.lightGray])
        
        self.update(with: self.loginInfo)
    }
    
    func update(with loginInfo: LoginInfo?) {
        self.userNameLabel.text = loginInfo?.auth?.userName
        self.passwordLabel.text = loginInfo?.auth?.password
        self.addressLabel.text = loginInfo?.url.absoluteString
    }
    
    //MARK: Private Method

    @objc private func onTouchLoginButton() {
        
        defer {
            self.view.endEditing(true)
        }
        
        var url: URL?
        
        if let address = self.addressLabel.text, !address.isEmpty {
            let characterSet = CharacterSet.urlQueryAllowed.union(CharacterSet.urlPathAllowed)
            if let urlString = address.addingPercentEncoding(withAllowedCharacters: characterSet) {
                url = URL(string: urlString)
            }
        }
        
        guard let url = url else {
            self.view.showHUD(NSLocalizedString("服务器地址格式不正确！", comment: ""))
            return
        }
        
        let userName = self.userNameLabel.text
        
        let auth: Auth? = .init(userName: userName, password: self.passwordLabel.text)
        let loginInfo = LoginInfo(url: url, auth:auth)
        self.loginWithInfo(loginInfo)
    }
    
    
    private func loginWithInfo(_ info: LoginInfo) {
        let progressHUD = self.view.showProgress()
        progressHUD.mode = .indeterminate
        
        self.fileManager.connectWithLoginInfo(info) { [weak self, weak progressHUD] (error) in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    progressHUD?.hide(animated: true)
                    self.view.showError(error)
                }
            } else {
                DispatchQueue.main.async {
                    progressHUD?.hide(animated: true)
                    
                    self.delegate?.viewControllerDidSuccessConnected(self, loginInfo: info)
                }
            }
        }
    }

}
