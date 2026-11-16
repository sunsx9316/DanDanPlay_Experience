//
//  PlayerLaunchViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/5.
//

import Cocoa
import SnapKit

/// 播放器首页的外壳，保留 MainViewController 原有的调用方式。
/// 实际界面由 WelcomeShellViewController 提供。
class PlayerLaunchViewController: ViewController {

    var onOpenFiles: (([File], File?) -> Void)? {
        get { shellVC.onOpenFiles }
        set { shellVC.onOpenFiles = newValue }
    }

    /// “继续播放”专用：在打开文件的同时恢复指定进度（0...1）。
    var onResumeFiles: (([File], File?, Double) -> Void)? {
        get { shellVC.onResumeFiles }
        set { shellVC.onResumeFiles = newValue }
    }

    var onOpenNetworkFile: (() -> Void)? {
        get { shellVC.onOpenNetworkFile }
        set { shellVC.onOpenNetworkFile = newValue }
    }

    var onShowHomePage: (() -> Void)? {
        get { shellVC.onShowHomePage }
        set { shellVC.onShowHomePage = newValue }
    }

    var onShowSettings: (() -> Void)? {
        get { shellVC.onShowSettings }
        set { shellVC.onShowSettings = newValue }
    }

    var onShowMembership: (() -> Void)? {
        get { shellVC.onShowMembership }
        set { shellVC.onShowMembership = newValue }
    }

    private lazy var shellVC: WelcomeShellViewController = {
        return WelcomeShellViewController()
    }()

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 1100, height: 720))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = AppInfoHelper.appDisplayName

        addChild(shellVC)
        view.addSubview(shellVC.view)
        shellVC.view.snp.makeConstraints { make in
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
        shellVC.presentLocalFilePicker()
    }
}
