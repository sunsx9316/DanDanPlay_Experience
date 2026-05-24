//
//  LocalFileBrowserViewController.swift
//  AniXPlayer
//
//  tvOS 本地文件浏览 — 继承 FileBrowserViewController，添加 WiFi 传文件按钮
//

import UIKit
import SnapKit

class LocalFileBrowserViewController: FileBrowserViewController {

    // MARK: - UI

    private lazy var wifiButton: Button = {
        let button = Button(type: .system)
        button.setImage(UIImage(systemName: "wifi"), for: .normal)
        button.setTitle(NSLocalizedString("WiFi传文件", comment: ""), for: .normal)
        button.addTarget(self, action: #selector(openWiFiTransfer), for: .primaryActionTriggered)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(wifiButton)

        wifiButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(8)
            make.trailing.equalToSuperview().offset(-20)
        }

        tableView.snp.remakeConstraints { make in
            make.top.equalTo(wifiButton.snp.bottom).offset(8)
            make.trailing.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(40)
        }
    }

    // MARK: - Actions

    @objc private func openWiFiTransfer() {
        let httpVC = HttpServerViewController()
        navigationController?.pushViewController(httpVC, animated: true)
    }

    // MARK: - Override

    override func selectFile(_ file: File) {
        if let delegate = delegate {
            delegate.fileBrowserViewController(self, didSelectFile: file, allFiles: files)
        } else {
            let playerVC = PlayerViewController(items: files, selectedItem: file)
            present(playerVC, animated: true)
        }
    }

    override func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        if let delegate = delegate {
            delegate.fileBrowserViewController(vc, didSelectFile: didSelectFile, allFiles: allFiles)
        } else {
            let playerVC = PlayerViewController(items: allFiles, selectedItem: didSelectFile)
            present(playerVC, animated: true)
        }
    }
}
