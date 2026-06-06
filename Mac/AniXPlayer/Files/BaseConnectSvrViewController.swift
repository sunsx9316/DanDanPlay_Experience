//
//  BaseConnectSvrViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa
import SnapKit


class BaseConnectSvrViewController: ViewController {

    weak var navigator: MediaLibraryNavigation?
    var onSuccessConnected: ((LoginInfo) -> Void)?

    let fileManager: FileManagerProtocol
    private let initialLoginInfo: LoginInfo?

    private(set) var loginInfo: LoginInfo?

    private lazy var backButton: NSButton = {
        let btn = NSButton(title: NSLocalizedString("← 返回", comment: ""), target: self, action: #selector(onTouchBackButton))
        btn.bezelStyle = .inline
        btn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return btn
    }()

    lazy var addressField: NSTextField = {
        let tf = NSTextField()
        tf.placeholderString = fileManager.addressExampleDesc
        return tf
    }()

    lazy var userNameField: NSTextField = {
        let tf = NSTextField()
        tf.placeholderString = NSLocalizedString("登录用户名", comment: "")
        return tf
    }()

    lazy var passwordField: NSSecureTextField = {
        let tf = NSSecureTextField()
        tf.placeholderString = fileManager.passwordDesc
        tf.isAutomaticTextCompletionEnabled = false
        return tf
    }()

    lazy var remarkField: NSTextField = {
        let tf = NSTextField()
        tf.placeholderString = NSLocalizedString("备注", comment: "")
        return tf
    }()

    private lazy var loginButton: NSButton = {
        let btn = NSButton(title: NSLocalizedString("登录", comment: ""), target: self, action: #selector(onTouchLoginButton))
        btn.bezelStyle = .rounded
        btn.keyEquivalent = "\r"
        return btn
    }()

    init(loginInfo: LoginInfo?, fileManager: FileManagerProtocol) {
        self.initialLoginInfo = loginInfo
        self.fileManager = fileManager
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    let formStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        let headerStack = NSStackView(views: [backButton, NSTextField(labelWithString: NSLocalizedString("登录", comment: ""))])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        headerStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        let addressRow = makeFormRow(label: NSLocalizedString("地址", comment: ""), field: addressField)
        formStack.addArrangedSubview(addressRow)
        addressRow.snp.makeConstraints { make in
            make.width.equalTo(formStack).offset(-40)
        }

        if fileManager.isRequiredUserName {
            let userRow = makeFormRow(label: NSLocalizedString("用户名", comment: ""), field: userNameField)
            formStack.addArrangedSubview(userRow)
            userRow.snp.makeConstraints { make in
                make.width.equalTo(formStack).offset(-40)
            }
        }

        let passwordRow = makeFormRow(label: NSLocalizedString("密码", comment: ""), field: passwordField)
        formStack.addArrangedSubview(passwordRow)
        passwordRow.snp.makeConstraints { make in
            make.width.equalTo(formStack).offset(-40)
        }

        let remarkRow = makeFormRow(label: NSLocalizedString("备注", comment: ""), field: remarkField)
        formStack.addArrangedSubview(remarkRow)
        remarkRow.snp.makeConstraints { make in
            make.width.equalTo(formStack).offset(-40)
        }

        formStack.addArrangedSubview(loginButton)
        loginButton.snp.makeConstraints { make in
            make.width.equalTo(120)
            make.height.equalTo(32)
        }

        view.addSubview(headerStack)
        view.addSubview(formStack)

        headerStack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }

        formStack.snp.makeConstraints { make in
            make.top.equalTo(headerStack.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
        }

        update(with: initialLoginInfo)
    }

    func makeFormRow(label: String, field: NSView) -> NSStackView {
        let lbl = NSTextField(labelWithString: label + ":")
        lbl.alignment = .right
        lbl.font = .systemFont(ofSize: 13)
        lbl.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let row = NSStackView(views: [lbl, field])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.distribution = .fill

        lbl.snp.makeConstraints { make in
            make.width.equalTo(60)
        }

        return row
    }

    // MARK: - Methods for override

    func createAuth() -> Auth? {
        return Auth(userName: userNameField.stringValue, password: passwordField.stringValue)
    }

    func update(with loginInfo: LoginInfo?) {
        addressField.stringValue = loginInfo?.url.absoluteString ?? ""
        userNameField.stringValue = loginInfo?.auth?.userName ?? ""
        passwordField.stringValue = loginInfo?.auth?.password ?? ""
        remarkField.stringValue = loginInfo?.remark ?? ""
    }

    // MARK: - Actions

    @objc private func onTouchBackButton() {
        navigator?.popViewController()
    }

    @objc private func onTouchLoginButton() {
        let address = addressField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, let url = URL(string: address) else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("服务器地址格式不正确！", comment: "")
            alert.beginSheetModal(for: view.window!)
            return
        }

        let loginInfo = LoginInfo(
            url: url,
            auth: createAuth(),
            remark: remarkField.stringValue
        )

        view.showLoading(statusText: NSLocalizedString("连接中...", comment: ""))
        fileManager.connectWithLoginInfo(loginInfo) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.view.dismiss(delay: 0)
                if let error = error {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!)
                } else {
                    self.loginInfo = loginInfo
                    self.navigator?.popViewController()
                    self.onSuccessConnected?(loginInfo)
                }
            }
        }
    }
}
