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
        vc.onOpenNetworkFile = { [weak self] in
            self?.showNetworkFiles()
        }
        vc.onShowHomePage = { [weak self] in
            self?.showHomePage()
        }
        vc.onShowSettings = { [weak self] in
            self?.showSettings()
        }
        // 会员中心暂未接入 macOS 端，保留可选回调，欢迎页会显示为禁用状态。
        vc.onShowMembership = nil
        return vc
    }()

    private var playerVC: PlayerViewController?

    private var homePageWindowController: HomePageNavigationWindowController?

    private var mediaLibraryWindowController: MediaLibraryWindowController?

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 800, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = AppInfoHelper.appDisplayName
        view.setAccessibilityIdentifier(AccessibilityID.Launch.root)
        showLaunch()
    }

    func openNetworkFiles(_ files: [File], startWith file: File) {
        showPlayer(with: files, startWith: file)
    }

    func openLocalFiles(_ files: [File], startWith file: File?) {
        showPlayer(with: files, startWith: file)
    }

    /// L2 播放冒烟：当前播放器状态；没有播放器时返回 nil。
    var currentPlaybackSnapshot: PlaybackSnapshot? {
        return playerVC?.playbackSnapshot()
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
        if let recentFile = file ?? files.first(where: { $0.url.isFileURL }) {
            WelcomeRecentStore.shared.record(file: recentFile)
        }

        let vc = PlayerViewController()
        vc.onStopCallBack = { [weak self] in
            self?.rememberCurrentPlayback()
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

    private func rememberCurrentPlayback() {
        guard let playerVC = playerVC,
              let file = playerVC.currentMediaFile else { return }

        let snapshot = playerVC.playbackSnapshot()
        let progress: Double?
        if snapshot.duration > 0 {
            let fraction = max(0, min(snapshot.position / snapshot.duration, 1))
            // 播放到结尾时清空进度，避免下次从片尾继续。
            progress = fraction >= 0.99 ? 0 : fraction
        } else {
            progress = nil
        }
        WelcomeRecentStore.shared.record(file: file, progress: progress)
    }

    // MARK: - Welcome shortcuts

    private func showNetworkFiles() {
        if let wc = mediaLibraryWindowController {
            wc.window?.makeKeyAndOrderFront(nil)
            return
        }

        let wc = MediaLibraryWindowController()
        wc.onSelectFile = { [weak self] file, allFiles in
            guard let self = self else { return }
            self.openNetworkFiles(allFiles, startWith: file)
            self.view.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        wc.windowWillCloseCallBack = { [weak self] in
            self?.mediaLibraryWindowController = nil
        }
        wc.showWindow(nil)
        mediaLibraryWindowController = wc
    }

    private func showHomePage() {
        if let wc = homePageWindowController {
            wc.window?.makeKeyAndOrderFront(nil)
            return
        }

        let homeVC = HomePageViewController()
        let wc = HomePageNavigationWindowController(rootViewController: homeVC)
        homeVC.navigator = wc
        wc.windowWillCloseCallBack = { [weak self] in
            self?.homePageWindowController = nil
        }
        wc.showWindow(nil)
        homePageWindowController = wc
    }

    private func showSettings() {
        let vc = GlobalSettingViewController()
        self.presentAsModalWindow(vc)
    }
}
