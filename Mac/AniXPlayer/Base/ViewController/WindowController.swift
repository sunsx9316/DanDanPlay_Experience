//
//  WindowController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/17.
//

import Cocoa

class WindowController: NSWindowController, NSWindowDelegate {
    
    var windowWillCloseCallBack: (() -> Void)?
    
    convenience init() {
        let nibName = "\(type(of: self).self)"
        self.init(windowNibName: nibName)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    override func loadWindow() {
        let bundle = Bundle(for: type(of: self)).path(forResource: self.windowNibName, ofType: "nib")
        if bundle != nil {
            super.loadWindow()
        } else {
            self.window = .init()
            self.window?.delegate = self
            self.window?.styleMask.insert([.titled, .closable, .resizable])
            self.window?.isRestorable = false
        }
    }
    
    func showAtCenter(_ window: NSWindow?) {
        
        var frame = self.window!.frame
        let otherFrame = window?.frame ?? .zero
        
        frame.origin.x = otherFrame.origin.x + (otherFrame.width - frame.width) / 2
        frame.origin.y = otherFrame.origin.y + (otherFrame.height - frame.height) / 2
        self.window?.setFrame(frame, display: true)
        self.showWindow(nil)
    }
    
    func windowWillClose(_ notification: Notification) {
        self.windowWillCloseCallBack?()
    }
}
