//
//  PlayerWindowController.swift
//  dandanplay_native
//
//  Created by JimHuang on 2020/2/18.
//

import Cocoa
import DDPMediaPlayer

class PlayerWindowController: NSWindowController, NSWindowDelegate {
    
    private let windowFrameAutosaveKey = "playerViewController"
    
    var closeCallBack: (() -> Void)?
    
    lazy var playerViewController: PlayerViewController = {
        return PlayerViewController()
    }()

    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.window?.styleMask = [.miniaturizable, .closable, .resizable, .titled, .texturedBackground]
        self.window?.delegate = self
        self.window?.isMovableByWindowBackground = true
        self.window?.minSize = CGSize(width: 600, height: 400)
        self.contentViewController = self.playerViewController
        if let str = UserDefaults.standard.string(forKey: windowFrameAutosaveKey) {
            window?.setFrame(NSRectFromString(str), display: true)
        }
        
    }
    
    override func loadWindow() {
        self.window = NSWindow()
    }
    
    convenience init(items: [File]) {
        self.init(windowNibName: "PlayerWindowController")
        self.playerViewController.loadItem(items)
    }
    
    func windowWillClose(_ notification: Notification) {
        self.closeCallBack?()
        
        guard let frame = window?.frame else {
            return
        }
        
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: windowFrameAutosaveKey)
    }
    
}
