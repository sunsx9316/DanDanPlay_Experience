//
//  EmbyConnectViewController.swift
//  AniXPlayer
//
//  tvOS Emby 连接页面 — API Key / 用户名+密码双模式
//

import UIKit
import SnapKit
#if !os(tvOS)
import ANXLog
#endif

class EmbyConnectViewController: RemoteConnectViewController {

    private enum AuthMode: Int {
        case apiKey = 0
        case usernamePassword = 1
    }

    private var currentMode: AuthMode = .apiKey

    override var addressScheme: String { "http://" }

    // MARK: - UI

    private lazy var modeSegment: UISegmentedControl = {
        let segment = UISegmentedControl(items: [
            NSLocalizedString("API Key", comment: ""),
            NSLocalizedString("用户名+密码", comment: "")
        ])
        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(modeDidChange), for: .valueChanged)
        return segment
    }()

    private(set) lazy var apiKeyLabel: UITextField = {
        let tf = UITextField()
        tf.font = .ddp_normal()
        tf.textColor = .label
        tf.attributedPlaceholder = NSAttributedString(
            string: fileManager.apiKeyDesc,
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        return tf
    }()

    // MARK: - Init

    private let customTitle: String?

    init(loginInfo: LoginInfo? = nil, customTitle: String? = nil) {
        self.customTitle = customTitle
        super.init(loginInfo: loginInfo, fileManager: EmbyFileManager.shared)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        if let customTitle = customTitle {
            self.title = customTitle
        }
    }

    override func setupFields() {
        stackView.insertArrangedSubview(modeSegment, at: 0)
        modeSegment.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        super.setupFields()

        // 在 passwordLabel 之后插入 apiKeyLabel
        if let passwordIndex = stackView.arrangedSubviews.firstIndex(of: passwordLabel) {
            stackView.insertArrangedSubview(apiKeyLabel, at: passwordIndex + 1)
        }
        apiKeyLabel.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        // 恢复上次使用的模式
        if let info = loginInfo, let userName = info.auth?.userName, !userName.isEmpty {
            currentMode = .usernamePassword
            modeSegment.selectedSegmentIndex = AuthMode.usernamePassword.rawValue
        } else if let info = loginInfo, info.auth?.apiKey != nil {
            currentMode = .apiKey
            modeSegment.selectedSegmentIndex = AuthMode.apiKey.rawValue
        }

        updateUIForAuthMode()
    }

    override func update(with loginInfo: LoginInfo?) {
        super.update(with: loginInfo)
        apiKeyLabel.text = loginInfo?.auth?.apiKey
    }

    // MARK: - Actions

    @objc private func modeDidChange() {
        currentMode = AuthMode(rawValue: modeSegment.selectedSegmentIndex) ?? .apiKey
        if currentMode == .apiKey {
            userNameLabel.text = nil
        }
        updateUIForAuthMode()
    }

    private func updateUIForAuthMode() {
        let isAPIKey = currentMode == .apiKey
        userNameLabel.isHidden = isAPIKey
        passwordLabel.isHidden = isAPIKey
        apiKeyLabel.isHidden = !isAPIKey
    }

    override func onTouchLoginButton() {
        view.endEditing(true)

        let addressText = addressLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !addressText.isEmpty else {
            view.showHUD(NSLocalizedString("请输入服务器地址", comment: ""))
            return
        }

        let urlString: String
        if addressText.contains("://") {
            urlString = addressText
        } else {
            urlString = addressScheme + addressText
        }

        guard let url = URL(string: urlString) else {
            view.showHUD(NSLocalizedString("服务器地址格式不正确！", comment: ""))
            return
        }

        let auth: Auth
        if currentMode == .apiKey {
            auth = Auth(userName: nil, password: nil, apiKey: apiKeyLabel.text)
        } else {
            auth = Auth(userName: userNameLabel.text, password: passwordLabel.text)
        }

        let remark = remarkTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = LoginInfo(url: url, auth: auth, parameter: nil, remark: remark?.isEmpty == false ? remark : nil)
        loginWithInfo(info)
    }

    private func loginWithInfo(_ info: LoginInfo) {
        let hud = view.showLoading()

        fileManager.connectWithLoginInfo(info) { [weak self] error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                hud.hide(animated: true)

                if let error = error {
                    ANX.logError(.webDav, "Emby 连接失败 error: %@", error as NSError)
                    self.view.showHUD(error.localizedDescription)
                } else {
                    self.delegate?.connectViewController(self, didSuccessConnect: info)
                }
            }
        }
    }
}
