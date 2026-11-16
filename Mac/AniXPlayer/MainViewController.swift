//
//  MainViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/5.
//

import Cocoa
import SnapKit

class MainViewController: ViewController {

    private lazy var shellVC: MainShellViewController = {
        let vc = MainShellViewController()
        vc.onOpenFiles = { [weak self] files, startFile in
            self?.showPlayer(with: files, startWith: startFile)
        }
        vc.onResumeFiles = { [weak self] files, startFile, progress in
            self?.showPlayer(with: files, startWith: startFile, progress: progress)
        }
        vc.onOpenNetworkFile = { [weak self] in
            self?.showNetworkFiles()
        }
        vc.onShowSettings = { [weak self] in
            self?.showSettings()
        }
        vc.onShowMembership = {
            MacFeatureLauncher.showMembership()
        }
        vc.onPlayFiles = { [weak self] files, startFile in
            self?.showPlayer(with: files, startWith: startFile)
        }
        return vc
    }()

    private var playerWindowController: PlayerWindowController?

    private var mediaLibraryWindowController: MediaLibraryWindowController?

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 980, height: 680))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = AppInfoHelper.appDisplayName
        view.setAccessibilityIdentifier(AccessibilityID.Launch.root)
        showShell()
    }

    /// 菜单/其他窗口切回主窗口指定分区。
    func showMainSection(_ section: MainShellSection) {
        _ = view
        shellVC.select(section)
        view.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openNetworkFiles(_ files: [File], startWith file: File, progress: Double? = nil) {
        showPlayer(with: files, startWith: file, progress: progress)
    }

    func openLocalFiles(_ files: [File], startWith file: File?, progress: Double? = nil) {
        showPlayer(with: files, startWith: file, progress: progress)
    }

    /// 详情页「搜索资源」：切到搜索分区并预填番剧标题。
    func openResourceSearch(keyword: String) {
        _ = view
        shellVC.openResourceSearch(keyword: keyword)
        view.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 详情页「在线观看」：切到首页在线观看并预填番剧标题。
    func openOnlineSearch(keyword: String) {
        _ = view
        shellVC.openOnlineSearch(keyword: keyword)
        view.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 菜单入口：对当前播放器导出 GIF；没有播放器时给出提示。
    func exportCurrentPlayerGIF() {
        guard let player = playerWindowController?.playerViewController else {
            view.show(text: NSLocalizedString("请先打开视频", comment: ""))
            return
        }
        player.exportGIF()
    }

    /// L2 播放冒烟：当前播放器状态；没有播放器时返回 nil。
    var currentPlaybackSnapshot: PlaybackSnapshot? {
        return playerWindowController?.playerViewController.playbackSnapshot()
    }

    // MARK: - Private

    private func showShell() {
        addChild(shellVC)
        view.addSubview(shellVC.view)
        shellVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func showPlayer(with files: [File], startWith file: File?, progress: Double? = nil) {
        if let recentFile = file ?? files.first(where: { $0.url.isFileURL }) {
            WelcomeRecentStore.shared.record(file: recentFile)
        }

        // 已有播放器窗口时复用：先保存旧媒体的进度，再在同一窗口加载新文件。
        if let existing = playerWindowController {
            self.rememberCurrentPlayback(for: existing.playerViewController)
            existing.playerViewController.loadFiles(files, startWith: file, progress: progress)
            existing.focusPlayer()
            return
        }

        let vc = PlayerViewController()
        vc.backupDanmakuAccessCheck = { [weak self] in
            await EntitlementGate.shared.require(
                .member,
                feature: .backupDanmaku,
                presenting: self?.view.window
            )
        }
        vc.gifExportAccessCheck = { [weak self] in
            await EntitlementGate.shared.require(
                .member,
                feature: .gifExport,
                presenting: self?.view.window
            )
        }
        vc.onStopCallBack = { [weak self] in
            self?.stopAndClosePlayerWindow()
        }

        let wc = PlayerWindowController(playerViewController: vc)
        wc.onClose = { [weak self] in
            self?.playerWindowDidClose()
        }

        playerWindowController = wc
        wc.showWindow(nil)
        wc.window?.center()

        vc.loadFiles(files, startWith: file, progress: progress)
    }

    private func stopAndClosePlayerWindow() {
        guard let wc = playerWindowController else { return }
        self.rememberCurrentPlayback(for: wc.playerViewController)
        wc.close()
    }

    private func playerWindowDidClose() {
        self.rememberCurrentPlayback(for: playerWindowController?.playerViewController)
        playerWindowController = nil

        // 欢迎页仍留在主窗口；播完/停止后把焦点还给主窗口。
        self.view.window?.makeKeyAndOrderFront(nil)
    }

    private func rememberCurrentPlayback(for playerVC: PlayerViewController?) {
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
        WelcomeRecentStore.shared.record(
            file: file,
            progress: progress,
            position: snapshot.duration > 0 ? snapshot.position : nil,
            duration: snapshot.duration > 0 ? snapshot.duration : nil
        )
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
            NSApp.activate(ignoringOtherApps: true)
        }
        wc.windowWillCloseCallBack = { [weak self] in
            self?.mediaLibraryWindowController = nil
        }
        wc.showWindow(nil)
        mediaLibraryWindowController = wc
    }

    private func showSettings() {
        let vc = GlobalSettingViewController()
        self.presentAsModalWindow(vc)
    }
}
