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

    private var localLibraryWindowController: LocalLibraryWindowController?

    private var downloadWindowController: DownloadWindowController?

    private var playHistoryWindowController: PlayHistoryNavigationWindowController?

    private var bangumiQueueWindowController: BangumiQueueNavigationWindowController?

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

        // 下载中心在后台继续下载：启动时恢复未完成任务（测试/冒烟模式跳过副作用）。
        if !Self.isRunningUnitTests && !PlaybackSmokeRunner.isSmokeInvocation {
            DownloadNotifier.shared.activate()
            DownloadNotifier.shared.onSelectTask = { [weak self] taskID in
                Task { @MainActor in
                    self?.presentDownloadCenterWindow(selectingTaskID: taskID)
                }
            }
            DownloadManager.shared.bootstrap()
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

        // L2 冒烟自己负责打开 --open 指定的文件；AppKit 会把 --state-file 等
        // 参数后的路径也当成“待打开文档”，必须丢弃，否则会先创建播放器装错文件。
        guard !PlaybackSmokeRunner.isSmokeInvocation else { return }

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

        // 冒烟模式不处理 AppKit 的待打开文档（可能包含 --state-file 的路径）。
        guard !PlaybackSmokeRunner.isSmokeInvocation else { return }
        deliverOpenURLs(urls)
    }

    private func deliverOpenURLs(_ urls: [URL]) {
        var downloadSources: [String] = []
        var playerURLs: [URL] = []

        for url in urls {
            if let source = downloadSource(from: url) {
                downloadSources.append(source)
                continue
            }
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "magnet" || scheme == "ddplay" {
                // 已注册的下载协议但不是可识别的下载链接：不要交给播放器。
                continue
            }
            if url.isFileURL, url.pathExtension.lowercased() == "torrent" {
                continue
            }
            playerURLs.append(url)
        }

        if !downloadSources.isEmpty {
            Task { @MainActor in
                self.presentDownloadCenterWindow(prefillSources: downloadSources)
            }
        }

        guard !playerURLs.isEmpty else { return }
        guard let mainVC = mainWindowController.contentViewController as? MainViewController else { return }

        let files = expandLocalFiles(playerURLs)
        let videoFiles = files.filter { !$0.url.isSubtitleFile && !$0.url.isDanmakuFile }

        guard !videoFiles.isEmpty else {
            mainVC.view.show(text: NSLocalizedString("请先打开视频文件", comment: ""))
            return
        }

        mainWindowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainVC.openLocalFiles(videoFiles, startWith: nil)
    }

    /// 系统入口：magnet:/ddplay: 预填添加 sheet；本地 .torrent 先复制到 App 目录。
    private func downloadSource(from url: URL) -> String? {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "magnet" || scheme == "ddplay" {
            let absolute = url.absoluteString
            if scheme == "ddplay" {
                let lower = absolute.lowercased()
                guard lower.hasPrefix("ddplay:magnet:")
                    || lower.hasPrefix("ddplay://magnet:") else {
                    return nil
                }
            }
            do {
                return try DownloadSourceParser.parse(absolute).source
            } catch {
                presentOpenError(error.localizedDescription)
                return nil
            }
        }

        if url.isFileURL, url.pathExtension.lowercased() == "torrent" {
            do {
                return try DownloadTorrentImporter.importTorrent(at: url)
            } catch {
                presentOpenError(error.localizedDescription)
                return nil
            }
        }
        return nil
    }

    private func presentOpenError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("无法打开下载链接", comment: "")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("好", comment: ""))
        alert.runModal()
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
        mainWindowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let mainVC = mainWindowController.contentViewController as? MainViewController {
            mainVC.showMainSection(.home)
        }
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

    @objc private func exportCurrentGIF(_ item: NSMenuItem) {
        guard let main = mainWindowController.contentViewController as? MainViewController else { return }
        main.exportCurrentPlayerGIF()
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

    @objc private func showLocalLibrary(_ item: NSMenuItem) {
        Task { @MainActor in
            self.presentLocalLibraryWindow()
        }
    }

    @MainActor private func presentLocalLibraryWindow() {
        if let wc = localLibraryWindowController {
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let wc = LocalLibraryWindowController()
        wc.onPlayFiles = { [weak self] files, startFile in
            guard let self,
                  let mainVC = self.mainWindowController.contentViewController as? MainViewController else {
                return
            }
            self.mainWindowController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            mainVC.openLocalFiles(files, startWith: startFile)
        }
        wc.windowWillCloseCallBack = { [weak self] in
            self?.localLibraryWindowController = nil
        }
        wc.showWindow(nil)
        localLibraryWindowController = wc
    }

    @objc private func showDownloadCenter(_ item: NSMenuItem) {
        Task { @MainActor in
            self.presentDownloadCenterWindow()
        }
    }

    @objc private func addDownloadFromClipboard(_ item: NSMenuItem) {
        let pasteboard = NSPasteboard.general
        var rawValues: [String] = []
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            rawValues.append(string)
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            rawValues.append(contentsOf: urls.map { $0.path })
        }

        var sources: [String] = []
        for raw in rawValues {
            if let path = DownloadTorrentImporter.torrentPath(from: raw),
               let imported = try? DownloadTorrentImporter.importTorrent(
                   at: URL(fileURLWithPath: path)
               ) {
                sources.append(imported)
            } else if let parsed = try? DownloadSourceParser.parse(raw) {
                sources.append(parsed.source)
            }
        }
        guard !sources.isEmpty else {
            presentOpenError(NSLocalizedString(
                "剪贴板中没有可识别的磁力链接、种子文件或下载地址。",
                comment: ""
            ))
            return
        }

        Task { @MainActor in
            self.presentDownloadCenterWindow(prefillSources: sources)
        }
    }

    @objc private func pauseAllDownloads(_ item: NSMenuItem) {
        DownloadManager.shared.pauseAll()
    }

    @objc private func resumeAllDownloads(_ item: NSMenuItem) {
        DownloadManager.shared.resumeAll()
    }

    @MainActor private func presentDownloadCenterWindow(
        selectingTaskID: UUID? = nil,
        prefillSources: [String] = []
    ) {
        DownloadManager.shared.bootstrap()

        let wc: DownloadWindowController
        if let existing = downloadWindowController {
            wc = existing
        } else {
            let created = DownloadWindowController()
            created.onPlayFiles = { [weak self] files, startFile in
                guard let self,
                      let mainVC = self.mainWindowController.contentViewController as? MainViewController else {
                    return
                }
                self.mainWindowController.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                mainVC.openLocalFiles(files, startWith: startFile)
            }
            created.windowWillCloseCallBack = { [weak self] in
                self?.downloadWindowController = nil
            }
            created.showWindow(nil)
            downloadWindowController = created
            wc = created
        }

        wc.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let selectingTaskID {
            wc.revealTask(id: selectingTaskID)
        }
        if !prefillSources.isEmpty {
            wc.presentAddSheet(prefillSources: prefillSources)
        }
    }

    @objc private func showBangumiQueue(_ item: NSMenuItem) {
        Task { @MainActor in
            self.presentBangumiQueueWindow()
        }
    }

    @MainActor private func presentBangumiQueueWindow() {
        if let wc = bangumiQueueWindowController {
            wc.window?.makeKeyAndOrderFront(nil)
            return
        }
        let wc = BangumiQueueNavigationWindowController()
        wc.windowWillCloseCallBack = { [weak self] in
            self?.bangumiQueueWindowController = nil
        }
        wc.showWindow(nil)
        bangumiQueueWindowController = wc
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

    @objc private func showMediaSniffer(_ item: NSMenuItem) {
        let window = self.mainWindowController.window
        Task { @MainActor in
            MacFeatureLauncher.showMediaSniffer(presenting: window) { file in
                MacFeatureLauncher.playOnlineFile(file)
            }
        }
    }


    @objc private func onOpenNetworkStream(_ item: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("打开网络串流", comment: "")
        alert.informativeText = NSLocalizedString("请输入 http/https/m3u8 视频地址。", comment: "")
        alert.alertStyle = .informational

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 440, height: 24))
        field.placeholderString = "https://example.com/video.m3u8"
        alert.accessoryView = field
        alert.addButton(withTitle: NSLocalizedString("打开", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let input = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: input),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            let error = NSAlert()
            error.messageText = NSLocalizedString("地址无效", comment: "")
            error.informativeText = NSLocalizedString("只支持 http/https 视频或 m3u8 地址。", comment: "")
            error.runModal()
            return
        }

        let pathName = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .path
            .split(separator: "/")
            .last
            .map(String.init)
        let displayName = (pathName?.isEmpty == false ? pathName! : NSLocalizedString("网络串流", comment: ""))
        let file = OnlineEpisodeFile(
            streamURL: url,
            displayName: displayName,
            headers: [:],
            pageURL: nil,
            sourceName: nil
        )

        guard let main = mainWindowController.contentViewController as? MainViewController else { return }
        Task { @MainActor in
            guard await EntitlementGate.shared.require(
                .member,
                feature: .onlinePlayback,
                presenting: main.view.window
            ) else { return }
            main.openLocalFiles([file], startWith: file)
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

            fileMenu.addItem(NSMenuItem.separator())
            fileMenu.addItem(
                withTitle: NSLocalizedString("打开网络串流…", comment: ""),
                action: #selector(onOpenNetworkStream(_:)),
                keyEquivalent: ""
            )

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
            let mediaSnifferItem = NSMenuItem(
                title: NSLocalizedString("媒体嗅探…", comment: ""),
                action: #selector(showMediaSniffer(_:)),
                keyEquivalent: ""
            )
            mediaSnifferItem.identifier = NSUserInterfaceItemIdentifier(AccessibilityID.OnlineSniffer.menuOpen)
            menu.addItem(mediaSnifferItem)
            menu.addItem(withTitle: NSLocalizedString("播放历史", comment: ""), action: #selector(showPlayHistory(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("本地媒体库…", comment: ""), action: #selector(showLocalLibrary(_:)), keyEquivalent: "")
            let downloadItem = NSMenuItem(
                title: NSLocalizedString("下载中心…", comment: ""),
                action: #selector(showDownloadCenter(_:)),
                keyEquivalent: ""
            )
            downloadItem.identifier = NSUserInterfaceItemIdentifier(AccessibilityID.Download.menuOpen)
            menu.addItem(downloadItem)
            let clipboardDownloadItem = NSMenuItem(
                title: NSLocalizedString("从剪贴板添加下载…", comment: ""),
                action: #selector(addDownloadFromClipboard(_:)),
                keyEquivalent: ""
            )
            clipboardDownloadItem.identifier = NSUserInterfaceItemIdentifier(
                AccessibilityID.Download.menuFromClipboard
            )
            menu.addItem(clipboardDownloadItem)
            let pauseAllItem = NSMenuItem(
                title: NSLocalizedString("全部暂停下载", comment: ""),
                action: #selector(pauseAllDownloads(_:)),
                keyEquivalent: ""
            )
            pauseAllItem.identifier = NSUserInterfaceItemIdentifier(AccessibilityID.Download.menuPauseAll)
            menu.addItem(pauseAllItem)
            let resumeAllItem = NSMenuItem(
                title: NSLocalizedString("全部继续下载", comment: ""),
                action: #selector(resumeAllDownloads(_:)),
                keyEquivalent: ""
            )
            resumeAllItem.identifier = NSUserInterfaceItemIdentifier(AccessibilityID.Download.menuResumeAll)
            menu.addItem(resumeAllItem)
            menu.addItem(withTitle: NSLocalizedString("我的追番", comment: ""), action: #selector(showBangumiQueue(_:)), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: NSLocalizedString("全局设置", comment: ""), action: #selector(onGlobalSettingItemDidClick(_:)), keyEquivalent: ",")
            menu.addItem(withTitle: NSLocalizedString("会员中心", comment: ""), action: #selector(showMembership(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("翻译字幕…", comment: ""), action: #selector(showTranslation(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("AI 视频总结…", comment: ""), action: #selector(showSummary(_:)), keyEquivalent: "")
            let exportGIFItem = NSMenuItem(
                title: NSLocalizedString("导出动图…", comment: ""),
                action: #selector(exportCurrentGIF(_:)),
                keyEquivalent: ""
            )
            exportGIFItem.identifier = NSUserInterfaceItemIdentifier(AccessibilityID.Player.exportGIFItem)
            menu.addItem(exportGIFItem)

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

