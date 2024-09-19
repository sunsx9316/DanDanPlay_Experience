//
//  AppDelegate.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/8.
//

import Cocoa
import ANXLog_Objc
import FirebaseCore
import RxSwift

class AppDelegate: NSObject, NSApplicationDelegate {
    
    weak var fileMenu: NSMenu?
    
    weak var danmakuMenu: NSMenu?
    
    weak var playerMenu: NSMenu?
    
    private lazy var appVersionModel = AppVersionModel()
    
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
        FirebaseApp.configure()
        
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
        }
        
        vc.onClickOKCallBack = { vc in
            vc.dismiss(nil)
        }
        
        self.mainWindowController.contentViewController?.presentAsModalWindow(vc)
    }
    
    @objc private func checkUpdate() {
        _ = self.appVersionModel.checkUpdate().subscribe(onNext: { [weak self] info in
            guard let self = self else { return }
            
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
           
            let fileItem = NSMenuItem(title: NSLocalizedString("打开...", comment: ""), action: nil, keyEquivalent: "n")
            fileItem.tag = MenuTag.fileOpen.rawValue
            fileMenu.addItem(fileItem)
            
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
    
    @objc private func onAboutItemDidClick(_ item: NSMenuItem) {
        let vc = AboutViewController()
        self.mainWindowController.contentViewController?.presentAsModalWindow(vc)
    }

}

