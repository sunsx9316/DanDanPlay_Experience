//
//  AppDelegate.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/8.
//

import Cocoa
import ANXLog

class AppDelegate: NSObject, NSApplicationDelegate {
    
    weak var fileMenu: NSMenu?
    
    weak var danmakuMenu: NSMenu?
    
    weak var playerMenu: NSMenu?
    
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
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        self.setupMenu()
        self.mainWindowController.showWindow(nil)
        self.mainWindowController.window?.center()
        
        self.checkUpdate()
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
            Preferences.shared.lastUpdateVersion = info.version
        }
        
        vc.onClickOKCallBack = { vc in
            vc.dismiss(nil)
            Preferences.shared.lastUpdateVersion = info.version
        }
        
        self.mainWindowController.contentViewController?.presentAsModalWindow(vc)
    }
    
    @objc private func checkUpdate() {
        
        NetworkManager.shared.checkUpdate { [weak self] info, error in
            guard let self = self else { return }
            
            if let info = info,
               let appVersion = InfoPlistUtils.appBuildNumber {
                //有版本更新
                if info.version.compare(appVersion, options: .numeric) == .orderedDescending {
                    //是否忽略此版本更新
                    if info.version != Preferences.shared.lastUpdateVersion {
                        DispatchQueue.main.async {
                            self.showAppVersionVC(info)
                        }
                    }
                }
            }
        }
    }
    

    private func setupMenu() {

        func appItem() -> NSMenuItem {
            let mainAppMenuItem = NSMenuItem(title: InfoPlistUtils.appName, action: nil, keyEquivalent: "")
            let appMenu = NSMenu()
            appMenu.addItem(withTitle: NSLocalizedString("关于", comment: "") + InfoPlistUtils.appName, action: nil, keyEquivalent: "")
            appMenu.addItem(NSMenuItem.separator())
            appMenu.addItem(withTitle: NSLocalizedString("偏好设置", comment: ""), action: #selector(onGlobalSettingItemDidClick(_:)), keyEquivalent: ",")
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
            return mainAppMenuItem
        }
        
        func fileItem() -> NSMenuItem {
            let mainFileMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            
            let fileMenu = NSMenu(title: NSLocalizedString("文件", comment: ""))
            self.fileMenu = fileMenu
            mainFileMenuItem.submenu = fileMenu
            
            return mainFileMenuItem
        }
        
        let mainMenu = NSMenu()
        mainMenu.addItem(appItem())
        mainMenu.addItem(fileItem())

        NSApp.mainMenu = mainMenu
    }
    
    @objc private func onGlobalSettingItemDidClick(_ item: NSMenuItem) {
        let vc = GlobalSettingViewController()
        self.mainWindowController.contentViewController?.presentAsModalWindow(vc)
    }

}

