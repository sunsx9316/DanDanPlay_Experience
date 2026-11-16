//
//  WelcomeDetailPresenter.swift
//  AniXPlayer
//
//  macOS：欢迎页外壳里打开作品详情 / 追番队列独立窗口。
//  不依赖 ViewController.navigator，避免把新的导航协议扩散到旧界面。
//

import Cocoa

@MainActor
final class WelcomeDetailPresenter {
    static let shared = WelcomeDetailPresenter()

    private var windowController: NavigationWindowController?

    private init() {}

    func open(animeId: Int, presenting window: NSWindow? = nil) {
        guard animeId > 0 else { return }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: window ?? NSApp.keyWindow) else {
                return
            }
            self.openWindow(animeId: animeId)
        }
    }

    private func openWindow(animeId: Int) {
        if let existing = windowController, existing.window?.isVisible == true {
            existing.window?.close()
            windowController = nil
        }

        let detailVC = BangumiDetailViewController(animateId: animeId)
        let config = NavigationConfiguration(
            windowSize: NSSize(width: 1000, height: 760),
            defaultTitle: NSLocalizedString("作品详情", comment: ""),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            hasToolbar: true,
            fixedContentSize: false
        )
        let controller = NavigationWindowController(rootViewController: detailVC, config: config)
        controller.window?.identifier = NSUserInterfaceItemIdentifier(AccessibilityID.WelcomeShell.detailWindow)
        controller.windowWillCloseCallBack = { [weak self, weak controller] in
            guard let self = self, let controller = controller else { return }
            if self.windowController === controller {
                self.windowController = nil
            }
        }
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        windowController = controller
    }
}

@MainActor
final class WelcomeQueueWindowPresenter {
    static let shared = WelcomeQueueWindowPresenter()

    private var windowController: BangumiQueueNavigationWindowController?

    private init() {}

    func open(presenting window: NSWindow? = nil) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: window ?? NSApp.keyWindow) else {
                return
            }
            self.openWindow()
        }
    }

    private func openWindow() {
        if let existing = windowController {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = BangumiQueueNavigationWindowController()
        controller.window?.identifier = NSUserInterfaceItemIdentifier(AccessibilityID.WelcomeShell.queueWindow)
        controller.windowWillCloseCallBack = { [weak self, weak controller] in
            guard let self = self, let controller = controller else { return }
            if self.windowController === controller {
                self.windowController = nil
            }
        }
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        windowController = controller
    }
}
