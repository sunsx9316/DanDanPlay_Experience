//
//  PlayerWindowController.swift
//  dandanplay_native
//
//  Created by JimHuang on 2020/2/18.
//

import Cocoa

class PlayerWindowController: NSWindowController, NSWindowDelegate {
    
    private var urls = [URL]()
    private let windowFrameAutosaveKey = "playerViewController"
    
    var closeCallBack: (() -> Void)?

    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.window?.styleMask = [.miniaturizable, .closable, .resizable, .titled, .texturedBackground]
        self.window?.delegate = self
        self.window?.isMovableByWindowBackground = true
        self.window?.minSize = CGSize(width: 600, height: 400)
        self.contentViewController = PlayerViewController(urls: urls)
        
        if let str = UserDefaults.standard.string(forKey: windowFrameAutosaveKey) {
            window?.setFrame(NSRectFromString(str), display: true)
        }
        
    }
    
    override func loadWindow() {
        self.window = NSWindow()
    }
    
    convenience init(urls: [URL]) {
        self.init(windowNibName: "PlayerWindowController")
        self.urls = urls;
    }
    
    func windowWillClose(_ notification: Notification) {
        self.closeCallBack?()
        
        guard let frame = window?.frame else {
            return
        }
        
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: windowFrameAutosaveKey)
    }
    
}
