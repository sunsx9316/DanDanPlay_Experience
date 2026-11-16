//
//  PlayerLaunchViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/5.
//

import Cocoa
import SnapKit

/// 播放器首页的外壳，保留 MainViewController 原有的调用方式。
/// 实际界面由 WelcomeViewController 提供。
class PlayerLaunchViewController: ViewController {

    var onOpenFiles: (([File], File?) -> Void)? {
        get { welcomeVC.onOpenFiles }
        set { welcomeVC.onOpenFiles = newValue }
    }

    var onOpenNetworkFile: (() -> Void)? {
        get { welcomeVC.onOpenNetworkFile }
        set { welcomeVC.onOpenNetworkFile = newValue }
    }

    var onShowHomePage: (() -> Void)? {
        get { welcomeVC.onShowHomePage }
        set { welcomeVC.onShowHomePage = newValue }
    }

    var onShowSettings: (() -> Void)? {
        get { welcomeVC.onShowSettings }
        set { welcomeVC.onShowSettings = newValue }
    }

    var onShowMembership: (() -> Void)? {
        get { welcomeVC.onShowMembership }
        set { welcomeVC.onShowMembership = newValue }
    }

    private lazy var welcomeVC: WelcomeViewController = {
        return WelcomeViewController()
    }()

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 800, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = AppInfoHelper.appDisplayName

        addChild(welcomeVC)
        view.addSubview(welcomeVC.view)
        welcomeVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        setupMenu()
    }

    // MARK: - File Menu

    private func setupMenu() {
        if let fileItem = NSApp.appDelegate?.fileMenu?.item(withTag: MenuTag.fileOpen.rawValue) {
            fileItem.target = self
            fileItem.action = #selector(pickFile)
        }
    }

    // MARK: - Actions

    @objc private func pickFile() {
        welcomeVC.presentLocalFilePicker()
    }
}
