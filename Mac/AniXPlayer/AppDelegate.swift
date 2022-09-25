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
    

    private func setupMenu() {

        func appItem() -> NSMenuItem {
            let mainAppMenuItem = NSMenuItem(title: InfoPlistUtils.appName, action: nil, keyEquivalent: "")
            let appMenu = NSMenu()
            appMenu.addItem(withTitle: NSLocalizedString("关于", comment: "") + InfoPlistUtils.appName, action: nil, keyEquivalent: "")
            appMenu.addItem(NSMenuItem.separator())
            appMenu.addItem(withTitle: NSLocalizedString("偏好设置", comment: ""), action: nil, keyEquivalent: ",")
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

}

