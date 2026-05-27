//
//  LocalFileBrowserViewController.swift
//  AniXPlayer
//
//  tvOS 本地文件浏览 — 继承 FileBrowserViewController，添加 WiFi 传文件按钮
//

import UIKit
import SnapKit

class LocalFileBrowserViewController: FileBrowserViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let wifiItem = UIBarButtonItem(title: NSLocalizedString("WiFi传文件", comment: ""), style: .plain, target: self, action: #selector(openWiFiTransfer))
        navigationItem.rightBarButtonItem = wifiItem
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
