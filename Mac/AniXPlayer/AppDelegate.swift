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

    private var loginWindowController: NSWindowController?

    private var homePageWindowController: HomePageNavigationWindowController?

    private lazy var mainWindowController: WindowController = {
        let mainWindowController = WindowController()
        mainWindowController.contentViewController = PlayerViewController()
        mainWindowController.window?.title = InfoPlistUtils.appName
        mainWindowController.window?.isReleasedWhenClosed = true
        mainWindowController.window?.setFrameAutosaveName("MainWindow")
        mainWindowController.windowWillCloseCallBack = {
            NSApp.terminate(nil)
        }
        return mainWindowController
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        Launcher.launch()
        
        self.setupMenu()
        self.mainWindowController.showWindow(nil)
        self.mainWindowController.window?.center()
        
        self.checkUpdate()

        // 恢复 iCloud 同步（如果之前已开启）
        if Preferences.shared.icloudSyncEnabled {
            Preferences.shared.store.startSync()
        }

        renewLoginInfo()

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
        wc.showWindow(nil)
        homePageWindowController = wc
    }

    @objc private func onOpenNetworkFile(_ item: NSMenuItem) {
        let wc = MediaLibraryWindowController()
        wc.onSelectFile = { [weak self] file, allFiles in
            guard let self = self,
                  let playerVC = self.mainWindowController.contentViewController as? PlayerViewController else { return }
            playerVC.openNetworkFiles(allFiles, startWith: file)
            self.mainWindowController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
            let mainAppMenuItem = NSMenuItem(title: InfoPlistUtils.appName, action: nil, keyEquivalent: "")
            let appMenu = NSMenu()
            appMenu.addItem(withTitle: NSLocalizedString("关于", comment: "") + InfoPlistUtils.appName, action: #selector(onAboutItemDidClick(_:)), keyEquivalent: "")
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

            let fileItem = NSMenuItem(title: NSLocalizedString("打开...", comment: ""), action: nil, keyEquivalent: "n")
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
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: NSLocalizedString("全局设置", comment: ""), action: #selector(onGlobalSettingItemDidClick(_:)), keyEquivalent: ",")

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
        if Preferences.shared.loginInfo != nil {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("提示", comment: "")
            alert.informativeText = NSLocalizedString("确定退出登录吗？", comment: "")
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("确定", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))
            if alert.runModal() == .alertFirstButtonReturn {
                Preferences.shared.loginInfo = nil
            }
        } else {
            let vc = LoginViewController()
            let window = NSWindow(contentViewController: vc)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            let wc = NSWindowController(window: window)
            wc.showWindow(nil)
            self.loginWindowController = wc
        }
    }

    @objc private func updateUserMenuItem() {
        guard let item = userMenuItem else { return }
        if let info = Preferences.shared.loginInfo {
            item.title = info.screenName
            item.submenu = nil
            if !info.profileImage.isEmpty {
                loadAvatar(for: item, from: info.profileImage)
            }
        } else {
            item.title = NSLocalizedString("登录弹弹Play…", comment: "")
            item.image = nil
            item.submenu = nil
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

    private func renewLoginInfo() {
        guard let loginInfo = Preferences.shared.loginInfo,
              let tokenExpireTime = loginInfo.tokenExpireTime else { return }
        if tokenExpireTime < Date() {
            UserNetworkHandle.renew { loginInfo, _ in
                if let loginInfo = loginInfo {
                    Preferences.shared.loginInfo = loginInfo
                }
            }
        }
    }

}

