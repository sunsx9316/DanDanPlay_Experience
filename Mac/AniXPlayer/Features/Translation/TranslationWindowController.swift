//
//  TranslationWindowController.swift
//  AniXPlayer
//
//  macOS only：AI 字幕翻译窗口。
//
//  集成方负责菜单入口；本控制器只暴露 init(accessCheck:) 与 showWindow()。
//

import Cocoa

@MainActor
final class TranslationWindowController: NSWindowController, NSWindowDelegate {
    private let translationViewController: TranslationViewController

    /// - Parameter accessCheck: 登录后的会员门禁。默认放行，供后续接入 EntitlementGate。
    init(accessCheck: @escaping () async -> Bool = { true }) {
        let viewController = TranslationViewController(accessCheck: accessCheck)
        self.translationViewController = viewController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("翻译字幕", comment: "")
        window.minSize = NSSize(width: 760, height: 520)
        window.isReleasedWhenClosed = false
        window.contentViewController = viewController
        window.setAccessibilityIdentifier(AccessibilityID.Translation.window)
        window.setAccessibilityLabel(NSLocalizedString("翻译字幕", comment: ""))

        super.init(window: window)

        window.delegate = self
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        super.showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        translationViewController.cancelCurrentTranslation()
    }
}
