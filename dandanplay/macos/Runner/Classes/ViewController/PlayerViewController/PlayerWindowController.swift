//
//  PlayerWindowController.swift
//  dandanplay_native
//
//  Created by JimHuang on 2020/2/18.
//

import Cocoa

class PlayerWindowController: NSWindowController, NSWindowDelegate {
    
    private var urls = [URL]()
    
    var closeCallBack: (() -> Void)?

    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.window?.styleMask = [.miniaturizable, .closable, .resizable, .titled, .texturedBackground]
        self.window?.delegate = self
        self.window?.isMovableByWindowBackground = true
        self.window?.minSize = CGSize(width: 600, height: 400)
        self.contentViewController = PlayerViewController(urls: urls)
    }
    
    override func loadWindow() {
        self.window = NSWindow()
    }
    
    convenience init(urls: [URL]) {
        self.init(windowNibName: "PlayerWindowController")
        self.windowFrameAutosaveName = "playerViewController"
        self.shouldCascadeWindows = true
        self.urls = urls;
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        self.closeCallBack?()
        return true
    }

}
