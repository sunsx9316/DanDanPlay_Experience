//
//  AccountProfileWindowController.swift
//  AniXPlayer
//
//  macOS only：账号资料独立窗口。
//

import Cocoa

@MainActor
final class AccountProfileWindowController: NSWindowController {

    private static var activeController: AccountProfileWindowController?

    private let profileViewController: AccountProfileViewController

    init() {
        self.profileViewController = AccountProfileViewController()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("账号资料", comment: "")
        window.identifier = NSUserInterfaceItemIdentifier(AccessibilityID.Account.window)
        window.isReleasedWhenClosed = false
        window.contentViewController = profileViewController
        window.contentMinSize = NSSize(width: 460, height: 420)
        window.setContentSize(NSSize(width: 520, height: 560))
        window.center()

        super.init(window: window)

        window.delegate = self
        profileViewController.onLoggedOut = { [weak self] in
            self?.window?.close()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func present(presenting window: NSWindow? = nil) {
        if let active = activeController {
            NSApp.activate(ignoringOtherApps: true)
            active.window?.deminiaturize(nil)
            active.window?.makeKeyAndOrderFront(nil)
            return
        }

        let controller = AccountProfileWindowController()
        activeController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}

extension AccountProfileWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if Self.activeController === self {
            Self.activeController = nil
        }
    }
}
