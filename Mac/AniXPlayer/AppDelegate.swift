//
//  AppDelegate.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/8.
//

import Cocoa
import ANXLog
import FirebaseCore
import RxSwift
import Kingfisher

class AppDelegate: NSObject, NSApplicationDelegate {

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    weak var fileMenu: NSMenu?
    
    weak var danmakuMenu: NSMenu?
    
    weak var playerMenu: NSMenu?

    private weak var appMenu: NSMenu?

    private weak var userMenuItem: NSMenuItem?
    
    private lazy var appVersionModel = AppVersionModel()

    private var mediaLibraryWindowController: MediaLibraryWindowController?

    private var homePageWindowController: HomePageNavigationWindowController?

    private var playHistoryWindowController: PlayHistoryNavigationWindowController?

    private var searchWindowController: SearchWindowController?

    private var pendingOpenURLs: [URL] = []

    private var didFinishLaunching = false

    private lazy var mainWindowController: WindowController = {
        let mainVC = MainViewController()
        let wc = WindowController()
        wc.window?.setFrameAutosaveName("MainWindow")
        wc.windowWillCloseCallBack = {
            NSApp.terminate(nil)
        }
        wc.contentViewController = mainVC
        return wc
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        Launcher.launch()
        
        self.setupMenu()
        self.mainWindowController.showWindow(nil)
        self.mainWindowController.window?.center()

        // L2 播放冒烟入口（仅 Debug）：必须在登录弹窗/更新检查之前启动。
        PlaybackSmokeRunner.shared.start(
            mainViewController: self.mainWindowController.contentViewController as? MainViewController
        )
        Task { @MainActor in
            MacFeatureLauncher.installEntitlements()
        }

        if !Self.isRunningUnitTests {
            if !PlaybackSmokeRunner.shared.isActive {
                self.checkUpdate()
            }

            // 恢复 iCloud 同步（如果之前已开启）
            if Preferences.shared.icloudSyncEnabled {
                Preferences.shared.store.startSync()
            }

            // macOS：强制登录 + 纯 Bearer，并清理旧 JWT。
            // 冒烟模式不读 Keychain，避免无人值守运行时弹出钥匙串授权框。
            MacAuthBootstrap.start(restoreSession: !PlaybackSmokeRunner.shared.isActive)
            if !PlaybackSmokeRunner.shared.isActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    MacAuthBootstrap.presentLoginIfNeeded()
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showConflictAlert),
            name: .syncConflictDetected,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateUserMenuItem),
            name: .AnixUserLoginStateDidChange,
            object: nil
        )

        didFinishLaunching = true
        processPendingOpenURLs()
    }

    @objc private func showConflictAlert() {
        guard case .conflict(let conflicts) = Preferences.shared.syncStatus else { return }

        let count = conflicts.count
        let message = String(format: NSLocalizedString("发现 %d 项设置与 iCloud 数据不一致，请选择以哪一端为准：", comment: ""), count)

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("iCloud 同步冲突", comment: "")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("使用本机数据", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("使用 iCloud 数据", comment: ""))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Preferences.shared.resolveConflicts(useCloud: false)
        } else {
            Preferences.shared.resolveConflicts(useCloud: true)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        ANXLogHelper.close()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        ANXLogHelper.flush()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Open Files

    /// 双击视频 / `open -a AniXPlayer.app video.mp4` 的入口。
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        handleOpenURLs(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        handleOpenURLs(urls)
    }

    private func handleOpenURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        ANX.logInfo(.UI, "[App] 打开外部文件: \(urls.map { $0.lastPathComponent })")

        if didFinishLaunching {
            deliverOpenURLs(urls)
        } else {
            pendingOpenURLs.append(contentsOf: urls)
        }
    }

    private func processPendingOpenURLs() {
        guard !pendingOpenURLs.isEmpty else { return }
        let urls = pendingOpenURLs
        pendingOpenURLs.removeAll()
        deliverOpenURLs(urls)
    }

    private func deliverOpenURLs(_ urls: [URL]) {
        guard let mainVC = mainWindowController.contentViewController as? MainViewController else { return }

        let files = expandLocalFiles(urls)
        let videoFiles = files.filter { !$0.url.isSubtitleFile && !$0.url.isDanmakuFile }

        guard !videoFiles.isEmpty else {
            mainVC.view.show(text: NSLocalizedString("请先打开视频文件", comment: ""))
            return
        }

        mainWindowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainVC.openLocalFiles(videoFiles, startWith: nil)
    }

    /// 把文件夹展开成子文件；与 NSOpenPanel 的行为保持一致。
    private func expandLocalFiles(_ urls: [URL]) -> [File] {
        var files: [File] = []
        var directories: [File] = []

        for url in urls {
            let file = LocalFile(with: url)
            if file.type == .folder {
                directories.append(file)
            } else {
                files.append(file)
            }
        }

        guard !directories.isEmpty else {
            return files
        }

        let group = DispatchGroup()
        for directory in directories {
            group.enter()
            LocalFile.fileManager.contentsOfDirectory(at: directory, filterType: .all) { result in
                if case .success(let children) = result {
                    files.append(contentsOf: children)
                }
                group.leave()
            }
        }
        _ = group.wait(timeout: .distantFuture)
        return files
    }

    /// 单元测试宿主进程：跳过登录窗口、更新检查等启动副作用。
    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    private func showAppVersionVC(_ info: UpdateInfo) {
        let vc = AppVersionViewController(appVersiotn: info)
        vc.onClickCancelCallBack = { vc in
            vc.dismiss(nil)
        }
        
        vc.onClickOKCallBack = { vc in
            vc.dismiss(nil)
        }
        
        self.mainWindowController.contentViewController?.presentAsModalWindow(vc)
    }
    
    @objc private func showHomePage(_ item: NSMenuItem) {
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

    @objc private func showMembership(_ item: NSMenuItem) {
        let window = self.mainWindowController.window
        Task { @MainActor in
            MacFeatureLauncher.showMembership(presenting: window)
        }
    }

    @objc private func showTranslation(_ item: NSMenuItem) {
        let window = self.mainWindowController.window
        Task { @MainActor in
            MacFeatureLauncher.showTranslation(presenting: window)
        }
    }

    @objc private func showSummary(_ item: NSMenuItem) {
        let window = self.mainWindowController.window
        Task { @MainActor in
            MacFeatureLauncher.showSummary(presenting: window)
        }
    }

    @objc private func showPlayHistory(_ item: NSMenuItem) {
        if let wc = playHistoryWindowController {
            wc.window?.makeKeyAndOrderFront(nil)
            return
        }
        let wc = PlayHistoryNavigationWindowController()
        wc.windowWillCloseCallBack = { [weak self] in
            self?.playHistoryWindowController = nil
        }
        wc.showWindow(nil)
        playHistoryWindowController = wc
    }

    @objc private func showSearch(_ item: NSMenuItem) {
        Task { @MainActor in
            if let wc = self.searchWindowController {
                wc.window?.makeKeyAndOrderFront(nil)
                return
            }
            let wc = SearchWindowController()
            wc.windowWillCloseCallBack = { [weak self] in
                self?.searchWindowController = nil
            }
            wc.showWindow(nil)
            self.searchWindowController = wc
        }
    }

    @objc private func onOpenNetworkFile(_ item: NSMenuItem) {
        let wc = MediaLibraryWindowController()
        wc.onSelectFile = { [weak self] file, allFiles in
            guard let self = self,
                  let mainVC = self.mainWindowController.contentViewController as? MainViewController else { return }
            mainVC.openNetworkFiles(allFiles, startWith: file)
            NSApp.activate(ignoringOtherApps: true)
        }
        wc.windowWillCloseCallBack = { [weak self] in
            self?.mediaLibraryWindowController = nil
        }
        wc.showWindow(nil)
        self.mediaLibraryWindowController = wc
    }

    @objc private func checkUpdate() {
        _ = self.appVersionModel.checkUpdate().subscribe(onNext: { [weak self] info in
            guard let self = self, let info = info else { return }

            if self.appVersionModel.shouldUpdate(updateInfo: info) {
                self.showAppVersionVC(info)
            }
        })
    }

    private func setupMenu() {

        func appItem() -> NSMenuItem {
            let mainAppMenuItem = NSMenuItem(title: AppInfoHelper.appDisplayName, action: nil, keyEquivalent: "")
            let appMenu = NSMenu()
            appMenu.addItem(withTitle: NSLocalizedString("关于", comment: "") + AppInfoHelper.appDisplayName, action: #selector(onAboutItemDidClick(_:)), keyEquivalent: "")
            appMenu.addItem(NSMenuItem.separator())
            appMenu.addItem(withTitle: NSLocalizedString("隐藏", comment: ""), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
            appMenu.addItem({ () -> NSMenuItem in
                let m = NSMenuItem(title: NSLocalizedString("隐藏其他", comment: ""), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
                m.keyEquivalentModifierMask = [.command, .option]
                return m
            }())
            appMenu.addItem(withTitle: NSLocalizedString("全部显示", comment: ""), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
            appMenu.addItem(NSMenuItem.separator())
            appMenu.addItem(withTitle: NSLocalizedString("关闭", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            mainAppMenuItem.submenu = appMenu
            self.appMenu = appMenu
            return mainAppMenuItem
        }
        
        func fileItem() -> NSMenuItem {
            let mainFileMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

            let fileMenu = NSMenu(title: NSLocalizedString("文件", comment: ""))

            let fileItem = NSMenuItem(title: NSLocalizedString("打开本地文件...", comment: ""), action: nil, keyEquivalent: "n")
            fileItem.tag = MenuTag.fileOpen.rawValue
            fileMenu.addItem(fileItem)

            fileMenu.addItem(NSMenuItem.separator())

            let networkFileItem = NSMenuItem(title: NSLocalizedString("打开网络文件...", comment: ""), action: #selector(onOpenNetworkFile(_:)), keyEquivalent: "")
            fileMenu.addItem(networkFileItem)

            self.fileMenu = fileMenu
            mainFileMenuItem.submenu = fileMenu

            return mainFileMenuItem
        }
        
        func editItem() -> NSMenuItem {
            let mainEditMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            let editMenu = NSMenu(title: NSLocalizedString("编辑", comment: ""))
            editMenu.addItem(withTitle: NSLocalizedString("撤销", comment: ""), action: Selector(("undo:")), keyEquivalent: "z")
            editMenu.addItem(withTitle: NSLocalizedString("重做", comment: ""), action: Selector(("redo:")), keyEquivalent: "Z")
            editMenu.addItem(NSMenuItem.separator())
            editMenu.addItem(withTitle: NSLocalizedString("剪切", comment: ""), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
            editMenu.addItem(withTitle: NSLocalizedString("拷贝", comment: ""), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
            editMenu.addItem(withTitle: NSLocalizedString("粘贴", comment: ""), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
            editMenu.addItem(withTitle: NSLocalizedString("全选", comment: ""), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
            mainEditMenuItem.submenu = editMenu
            return mainEditMenuItem
        }

        func functionItem() -> NSMenuItem {
            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            let menu = NSMenu(title: NSLocalizedString("功能", comment: ""))

            menu.addItem(withTitle: NSLocalizedString("主页", comment: ""), action: #selector(showHomePage(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("搜索…", comment: ""), action: #selector(showSearch(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("播放历史", comment: ""), action: #selector(showPlayHistory(_:)), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: NSLocalizedString("全局设置", comment: ""), action: #selector(onGlobalSettingItemDidClick(_:)), keyEquivalent: ",")
            menu.addItem(withTitle: NSLocalizedString("会员中心", comment: ""), action: #selector(showMembership(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("翻译字幕…", comment: ""), action: #selector(showTranslation(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("AI 视频总结…", comment: ""), action: #selector(showSummary(_:)), keyEquivalent: "")

            menu.addItem(NSMenuItem.separator())

            let userItem = NSMenuItem()
            userItem.action = #selector(onUserMenuItemDidClick(_:))
            userItem.target = self
            menu.addItem(userItem)
            self.userMenuItem = userItem

            item.submenu = menu
            return item
        }

        let mainMenu = NSMenu()
        mainMenu.addItem(appItem())
        mainMenu.addItem(functionItem())
        mainMenu.addItem(fileItem())
        mainMenu.addItem(editItem())

        NSApp.mainMenu = mainMenu
        updateUserMenuItem()
    }

    @objc private func onGlobalSettingItemDidClick(_ item: NSMenuItem) {
        let vc = GlobalSettingViewController()
        self.mainWindowController.contentViewController?.presentAsModalWindow(vc)
    }
    
    @objc private func onAboutItemDidClick(_ item: NSMenuItem) {
        let vc = AboutViewController()
        self.mainWindowController.contentViewController?.presentAsModalWindow(vc)
    }

    @objc private func onUserMenuItemDidClick(_ item: NSMenuItem) {
        Task { @MainActor in
            if await SessionStore.shared.isLoggedIn() {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("提示", comment: "")
                alert.informativeText = NSLocalizedString("确定退出登录吗？", comment: "")
                alert.alertStyle = .warning
                alert.addButton(withTitle: NSLocalizedString("确定", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))
                if alert.runModal() == .alertFirstButtonReturn {
                    await SessionStore.shared.logout()
                }
            } else {
                _ = await LoginGate.shared.ensureLoggedIn(presenting: self.mainWindowController.window)
            }
        }
    }

    @objc private func updateUserMenuItem() {
        guard let item = userMenuItem else { return }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let isLoggedIn = await SessionStore.shared.isLoggedIn()
            let profile = await SessionStore.shared.currentProfile()

            if isLoggedIn, let profile = profile {
                item.title = profile.displayName
                item.submenu = nil
                if !profile.profileImage.isEmpty {
                    self.loadAvatar(for: item, from: profile.profileImage)
                } else {
                    item.image = nil
                }
            } else {
                item.title = NSLocalizedString("登录弹弹Play…", comment: "")
                item.image = nil
                item.submenu = nil
            }
        }
    }

    private func loadAvatar(for item: NSMenuItem, from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        KingfisherManager.shared.retrieveImage(with: url) { result in
            guard case .success(let value) = result else { return }
            let image = value.image
            let size = NSSize(width: 18, height: 18)
            let avatar = NSImage(size: size)
            avatar.lockFocus()
            let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: size.width / 2, yRadius: size.height / 2)
            path.addClip()
            image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
            avatar.unlockFocus()
            DispatchQueue.main.async {
                item.image = avatar
            }
        }
    }

}

