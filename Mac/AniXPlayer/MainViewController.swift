//
//  MainViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/5.
//

import Cocoa
import SnapKit

class MainViewController: ViewController {

    private lazy var launchVC: PlayerLaunchViewController = {
        let vc = PlayerLaunchViewController()
        vc.onOpenFiles = { [weak self] files, startFile in
            self?.showPlayer(with: files, startWith: startFile)
        }
        return vc
    }()

    private var playerVC: PlayerViewController?

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 800, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = AppInfoHelper.appDisplayName
        showLaunch()
    }

    func openNetworkFiles(_ files: [File], startWith file: File) {
        showPlayer(with: files, startWith: file)
    }

    // MARK: - Private

    private func showLaunch() {
        addChild(launchVC)
        view.addSubview(launchVC.view)
        launchVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func showPlayer(with files: [File], startWith file: File?) {
        let vc = PlayerViewController()
        vc.onStopCallBack = { [weak self] in
            self?.hidePlayer()
        }

        addChild(vc)
        view.addSubview(vc.view)
        vc.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        launchVC.view.removeFromSuperview()
        launchVC.removeFromParent()

        playerVC = vc
        view.window?.makeFirstResponder(vc)
        vc.loadFiles(files, startWith: file)
    }

    private func hidePlayer() {
        playerVC?.view.removeFromSuperview()
        playerVC?.removeFromParent()
        playerVC = nil

        showLaunch()
    }
}
