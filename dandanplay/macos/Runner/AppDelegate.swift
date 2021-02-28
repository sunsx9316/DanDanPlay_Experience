import Cocoa
import FlutterMacOS
import DDPShare
import DDPMediaPlayer

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
    
    private var statusItem: NSStatusItem?
    private var menuBarPopover: NSPopover?
    private let ignoreVersionKey = "ignoreVersion"
    @IBOutlet weak var subtitleMenuItem: NSMenuItem!
    @IBOutlet weak var subtitleDelayMenuItem: NSMenuItem!
    @IBOutlet weak var subtitleTrackMenuItem: NSMenuItem!
    
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(named: "status_bar_button")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "检查新版本", action: #selector(onClickCheckVersionMenu(_:)), keyEquivalent: ""))
        statusItem.menu = menu
        self.statusItem = statusItem;
        
        if Preferences.shared.checkUpdate {
            checkVersion(byManual: false)
        }
        
        if let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            applicationMenu.title = appName;
        }
    }
    
    @IBAction func onClickSettingMenu(_ sender: NSMenuItem) {
        
        if let vc = self.mainFlutterWindow.contentViewController as? MessageViewController {
            vc.push("setting")
        }
        
        mainFlutterWindow.makeKeyAndOrderFront(nil)
    }
    
    func showUpdatePopover(_ contant: AppVersionMessage) {
        
        func show() {
            
            guard let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
                let newVersion = contant.version,
                newVersion.compare(version, options: .numeric) == .orderedDescending else {
                    if contant.byManual {
                        NSApp.stopModal()
                        let alert = NSAlert()
                        alert.messageText = "提示"
                        alert.informativeText = "并没有更新"
                        alert.alertStyle = .informational
                        alert.runModal()
                    }
                    
                return
            }
            
            self.menuBarPopover?.close()
            if let button = self.statusItem?.button {
                let popover = NSPopover()
                popover.delegate = self
                popover.behavior = .semitransient
                let vc = AppVersionViewController(appVersiotn: contant)
                vc.onClickCancelCallBack = { [weak self] (vc) in
                    guard let self = self else {
                        return
                    }
                    
                    self.menuBarPopover?.close()
                }
                popover.contentViewController = vc
                popover.show(relativeTo: .zero, of: button, preferredEdge: .maxY)
                self.menuBarPopover = popover
            }
        }
        
        if contant.byManual {
            show()
        } else {
            if let oldVersion = UserDefaults.standard.string(forKey: self.ignoreVersionKey) {
                //新版本
                if contant.version != oldVersion {
                    show()
                }
            } else {
                show()
            }
        }
    }
    
    //MARK: Private Method
    @objc private func onClickCheckVersionMenu(_ item: NSMenuItem) {
        checkVersion(byManual: true)
    }
    
    private func checkVersion(byManual: Bool) {
        let msg = RequestAppVersionMessage()
        msg.byManual = byManual
        MessageHandler.sendMessage(msg)
    }
    
}

extension AppDelegate: NSPopoverDelegate, NSMenuDelegate {
    //MARK: NSPopoverDelegate
    func popoverDidClose(_ notification: Notification) {
        if let vc = self.menuBarPopover?.contentViewController as? AppVersionViewController {
            UserDefaults.standard.set(vc.appVersion?.version, forKey: self.ignoreVersionKey)            
        }
        self.menuBarPopover = nil
    }
    
    //MARK: NSMenuDelegate
    func menuNeedsUpdate(_ menu: NSMenu) {
        let delaySecond = Helper.shared.player?.subtitleDelay ?? 0
        self.subtitleDelayMenuItem.title = String(format: "字幕延迟 %.1f秒", delaySecond)
        
        self.subtitleTrackMenuItem.submenu?.removeAllItems()
        if let player = Helper.shared.player {
            
            self.subtitleTrackMenuItem.isEnabled = true
            var subtitleTitlesMenu = self.subtitleTrackMenuItem.submenu
            
            if subtitleTitlesMenu == nil {
                subtitleTitlesMenu = NSMenu()
                self.subtitleTrackMenuItem.submenu = subtitleTitlesMenu
            }
            
            let currentSubtitleIndex = player.currentSubtitle?.index
            
            for item in player.subtitleList {
                let menuItem = NSMenuItem(title: item.name, action: #selector(onClickSubtitleTrack(_:)), keyEquivalent: "")
                menuItem.representedObject = item
                menuItem.state = currentSubtitleIndex == item.index ? .on : .off
                subtitleTitlesMenu?.addItem(menuItem)
            }
            
        } else {
            self.subtitleTrackMenuItem.submenu = nil
            self.subtitleTrackMenuItem.isEnabled = false
        }
    }
    
    @objc private func onClickSubtitleTrack(_ item: NSMenuItem) {
        let subtitle = item.representedObject as? MediaPlayer.Subtitle
        Helper.shared.player?.currentSubtitle = subtitle
    }
}
