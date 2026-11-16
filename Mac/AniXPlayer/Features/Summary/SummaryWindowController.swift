//
//  SummaryWindowController.swift
//  AniXPlayer
//
//  macOS only：AI 视频总结独立窗口。
//

import Cocoa

@MainActor
final class SummaryWindowController: NSWindowController, NSWindowDelegate {
    init(accessCheck: @escaping SummaryViewController.AccessCheck = { true }) {
        let contentViewController = SummaryViewController(accessCheck: accessCheck)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("AI 视频总结", comment: "")
        window.minSize = NSSize(width: 620, height: 520)
        window.isReleasedWhenClosed = false
        window.contentViewController = contentViewController
        window.setAccessibilityIdentifier(AccessibilityID.Summary.window)

        super.init(window: window)

        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 显示窗口并提升到前台。
    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        (contentViewController as? SummaryViewController)?.cancelPendingWork()
    }
}
