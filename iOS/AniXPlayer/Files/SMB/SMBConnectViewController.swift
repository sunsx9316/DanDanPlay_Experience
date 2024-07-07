//
//  SMBConnectViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/29.
//

import UIKit

protocol SMBConnectViewControllerDelegate: AnyObject {
    func viewControllerDidSuccessConnected(_ viewController: SMBConnectViewController, loginInfo: LoginInfo)
}

class SMBConnectViewController: ViewController {
    
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
    
    private lazy var segmentedTipsLabel: Label = {
        let label = Label()
        label.text = NSLocalizedString("连接身份", comment: "")
        return label
    }()
    
    private lazy var segmentedControl: UISegmentedControl = {
        let button = UISegmentedControl(items: [NSLocalizedString("客人", comment: ""),
                                                NSLocalizedString("注册用户", comment: "")])
        button.tintColor = .mainColor
        button.setTitleTextAttributes([.foregroundColor : UIColor.black], for: .selected)
        button.setTitleTextAttributes([.foregroundColor : UIColor.gray], for: .normal)
        if #available(iOS 13.0, *) {
            button.selectedSegmentTintColor = .lightGray
        }
        button.addTarget(self, action: #selector(onTouchSegmented(_:)), for: .valueChanged)
        return button
    }()
    
    weak var delegate: SMBConnectViewControllerDelegate?
    
    private var loginInfo: LoginInfo?
    
    private let fileManager: FileManagerProtocol
    
    /// 按客人身份登录时使用的用户名
    private let guestName = "guest"
    
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
        
        let segmentedStackView = UIStackView()
        segmentedStackView.axis = .vertical
        segmentedStackView.spacing = 10
        segmentedStackView.alignment = .fill
        segmentedStackView.addArrangedSubview(self.segmentedTipsLabel)
        segmentedStackView.addArrangedSubview(self.segmentedControl)
        self.view.addSubview(segmentedStackView)
        

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 15
        stackView.addArrangedSubview(self.addressLabel)
        stackView.addArrangedSubview(self.userNameLabel)
        stackView.addArrangedSubview(self.passwordLabel)
        stackView.addArrangedSubview(self.loginButton)
        self.view.addSubview(stackView)
        
        
        segmentedStackView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.leading.equalTo(10)
            make.trailing.equalTo(-10)
        }
        
        stackView.snp.makeConstraints { make in
            make.top.equalTo(segmentedStackView.snp.bottom).offset(10)
            make.leading.trailing.equalTo(segmentedStackView)
        }
        
        self.addressLabel.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        
        self.userNameLabel.snp.makeConstraints { make in
            make.height.equalTo(self.addressLabel)
        }
        
        self.passwordLabel.snp.makeConstraints { make in
            make.height.equalTo(self.addressLabel)
        }
        
        self.loginButton.snp.makeConstraints { make in
            make.height.equalTo(self.addressLabel)
        }
        
        self.userNameLabel.text = self.loginInfo?.auth?.userName
        self.passwordLabel.text = self.loginInfo?.auth?.password
        self.addressLabel.text = self.loginInfo?.url.absoluteString
        self.addressLabel.attributedPlaceholder = .init(string: self.fileManager.addressExampleDesc,
                                                attributes: [.foregroundColor : UIColor.lightGray])
        
        let userName = self.loginInfo?.auth?.userName
        if userName?.isEmpty == false && userName != guestName {
            self.segmentedControl.selectedSegmentIndex = 1
            self.selectedIndex(1)
        } else {
            self.segmentedControl.selectedSegmentIndex = 0
            self.selectedIndex(0)
        }
    }
    
    //MARK: Private Method
    @objc private func onTouchSegmented(_ segmented: UISegmentedControl) {
        self.selectedIndex(segmented.selectedSegmentIndex)
    }

    private func selectedIndex(_ segmentIndex: Int) {
        if segmentIndex == 0 {
            self.userNameLabel.isHidden = true
            self.passwordLabel.isHidden = true
        } else {
            self.userNameLabel.isHidden = false
            self.passwordLabel.isHidden = false
        }
    }

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
        
        if self.segmentedControl.selectedSegmentIndex == 0 {

            let loginInfo = LoginInfo(url: url, auth: Auth(userName: guestName, password: nil))
            self.loginWithInfo(loginInfo)
        } else {
            
            let userName = self.userNameLabel.text
            
            guard let userName = userName,
                  !userName.isEmpty else {
                self.view.showHUD(NSLocalizedString("请输入登录用户名！", comment: ""))
                return
            }
            
            let auth: Auth? = .init(userName: userName, password: self.passwordLabel.text)
            let loginInfo = LoginInfo(url: url, auth:auth)
            self.loginWithInfo(loginInfo)
        }
    }
    
    
    private func loginWithInfo(_ info: LoginInfo) {
        let progressHUD = self.view.showProgress()
        progressHUD.mode = .indeterminate
        
        self.fileManager.connectWithLoginInfo(info) { [weak self, weak progressHUD] error in
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
