//
//  WebDavConnectViewController.swift
//  AniXPlayer
//
//  tvOS WebDAV 连接页面
//

import UIKit

class WebDavConnectViewController: RemoteConnectViewController {

    private lazy var rootPathLabel: UITextField = {
        let tf = UITextField()
        tf.font = .ddp_normal()
        tf.textColor = .label
        tf.attributedPlaceholder = NSAttributedString(
            string: NSLocalizedString("根路径（可选）", comment: ""),
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        return tf
    }()

    override var addressScheme: String { "http://" }

    init(loginInfo: LoginInfo? = nil) {
        super.init(loginInfo: loginInfo, fileManager: WebDavFileManager.shared)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupFields() {
        super.setupFields()

        stackView.insertArrangedSubview(rootPathLabel, at: stackView.arrangedSubviews.count - 2)
        rootPathLabel.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        // 补默认值
        if let path = loginInfo?.parameter?[LoginInfo.Key.webDavRootPath.rawValue], !path.isEmpty {
            rootPathLabel.text = path
        } else {
            rootPathLabel.text = "/"
        }
    }

    override func loginParameter() -> [String: String]? {
        let path = rootPathLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : [LoginInfo.Key.webDavRootPath.rawValue: path]
    }
}
