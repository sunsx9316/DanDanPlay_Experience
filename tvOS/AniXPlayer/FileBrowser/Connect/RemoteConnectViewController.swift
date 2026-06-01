//
//  RemoteConnectViewController.swift
//  AniXPlayer
//
//  tvOS 远程服务器连接基类 — 适配焦点驱动模式
//

import UIKit
import SnapKit
import ANXLog

protocol RemoteConnectViewControllerDelegate: AnyObject {
    func connectViewController(_ vc: RemoteConnectViewController, didSuccessConnect loginInfo: LoginInfo)
}

class RemoteConnectViewController: ViewController {

    // MARK: - Properties (subclass overrides)

    var addressScheme: String { "" }

    weak var delegate: RemoteConnectViewControllerDelegate?

    let fileManager: FileManagerProtocol

    var loginInfo: LoginInfo?

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.keyboardDismissMode = .onDrag
        return sv
    }()

    internal lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 20
        return stack
    }()

    private(set) lazy var addressLabel: UITextField = {
        let tf = UITextField()
        tf.delegate = self
        tf.keyboardType = .URL
        tf.font = .ddp_normal()
        tf.textColor = .label
        return tf
    }()

    private(set) lazy var userNameLabel: UITextField = {
        let tf = UITextField()
        tf.font = .ddp_normal()
        tf.textColor = .label
        tf.attributedPlaceholder = NSAttributedString(
            string: NSLocalizedString("用户名", comment: ""),
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        return tf
    }()

    private(set) lazy var passwordLabel: UITextField = {
        let tf = UITextField()
        tf.font = .ddp_normal()
        tf.textColor = .label
        tf.isSecureTextEntry = true
        tf.attributedPlaceholder = NSAttributedString(
            string: NSLocalizedString("密码", comment: ""),
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        return tf
    }()

    private(set) lazy var remarkTextField: UITextField = {
        let tf = UITextField()
        tf.font = .ddp_normal()
        tf.textColor = .label
        tf.attributedPlaceholder = NSAttributedString(
            string: NSLocalizedString("备注", comment: ""),
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        return tf
    }()

    private lazy var loginButton: Button = {
        let button = Button(type: .system)
        button.setTitle(NSLocalizedString("登录", comment: ""), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.black, for: .focused)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(onTouchLoginButton), for: .primaryActionTriggered)
        return button
    }()

    // MARK: - Init

    init(loginInfo: LoginInfo? = nil, fileManager: FileManagerProtocol) {
        self.loginInfo = loginInfo
        self.fileManager = fileManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = fileManager.desc

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        scrollView.snp.makeConstraints { make in
            make.top.bottom.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(scrollView).offset(20)
            make.leading.equalTo(scrollView).offset(120)
            make.trailing.equalTo(scrollView).offset(-120)
            make.bottom.equalTo(scrollView).offset(-40)
            make.width.equalTo(scrollView).offset(-240)
        }

        setupFields()
        update(with: loginInfo)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = loginInfo != nil ? loginButton : addressLabel
    }

    // MARK: - Subclass Override Point

    func setupFields() {
        let addressPlaceholder = fileManager.addressExampleDesc
        addressLabel.attributedPlaceholder = NSAttributedString(
            string: addressPlaceholder,
            attributes: [.foregroundColor: UIColor.lightGray]
        )

        stackView.addArrangedSubview(addressLabel)
        addressLabel.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        if fileManager.isRequiredUserName {
            stackView.addArrangedSubview(userNameLabel)
            userNameLabel.snp.makeConstraints { make in
                make.height.equalTo(60)
            }
        }

        stackView.addArrangedSubview(passwordLabel)
        passwordLabel.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        stackView.addArrangedSubview(remarkTextField)
        remarkTextField.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        stackView.addArrangedSubview(loginButton)
        loginButton.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        // 间距
        let spacer = UIView()
        stackView.addArrangedSubview(spacer)
    }

    func update(with loginInfo: LoginInfo?) {
        guard let info = loginInfo else { return }
        addressLabel.text = info.url.absoluteString
        userNameLabel.text = info.auth?.userName
        passwordLabel.text = info.auth?.password
        remarkTextField.text = info.remark
    }

    // MARK: - Actions

    @objc func onTouchLoginButton() {
        view.endEditing(true)

        let addressText = addressLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !addressText.isEmpty else {
            view.anx_showError(NSLocalizedString("请输入服务器地址", comment: ""))
            return
        }

        let urlString: String
        if addressText.contains("://") {
            urlString = addressText
        } else {
            urlString = addressScheme + addressText
        }

        guard let url = URL(string: urlString) else {
            view.anx_showError(NSLocalizedString("服务器地址格式不正确！", comment: ""))
            return
        }

        let auth = Auth(userName: userNameLabel.text, password: passwordLabel.text)
        let remark = remarkTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = LoginInfo(url: url, auth: auth, parameter: loginParameter(), remark: remark?.isEmpty == false ? remark : nil)

        loginWithInfo(info)
    }

    func loginParameter() -> [String: String]? {
        return nil
    }

    private func loginWithInfo(_ info: LoginInfo) {
        view.anx_showLoading(NSLocalizedString("连接中…", comment: ""))

        fileManager.connectWithLoginInfo(info) { [weak self] error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.view.anx_hideHUD()

                if let error = error {
                    ANX.logError(.webDav, "连接失败 error: %@", error as NSError)
                    self.view.anx_showError(error.localizedDescription)
                } else {
                    self.delegate?.connectViewController(self, didSuccessConnect: info)
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate

extension RemoteConnectViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == addressLabel,
           let text = textField.text,
           text.isEmpty,
           !addressScheme.isEmpty {
            textField.text = addressScheme
        }
    }
}

