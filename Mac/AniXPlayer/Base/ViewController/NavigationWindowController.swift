//
//  NavigationWindowController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/30.
//

import Cocoa

struct NavigationConfiguration {
    var windowSize: NSSize
    var defaultTitle: String
    var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
    var hasToolbar: Bool = false
    var fixedContentSize: Bool = false
}

private extension NSToolbarItem.Identifier {
    static let navBack = NSToolbarItem.Identifier("NavigationBack")
}

class NavigationWindowController: WindowController, NSToolbarDelegate {

    private let config: NavigationConfiguration

    private var navigationStack: [NSViewController] = []

    private weak var backItem: NSToolbarItem?

    init(rootViewController: NSViewController, config: NavigationConfiguration) {
        self.config = config
        let window = NSWindow(
            contentRect: .zero,
            styleMask: config.styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = config.defaultTitle
        super.init(window: window)

        window.contentViewController = rootViewController
        window.setContentSize(config.windowSize)
        window.center()
        navigationStack.append(rootViewController)
        (rootViewController as? ViewController)?.navigator = self

        if config.hasToolbar {
            let toolbar = NSToolbar(identifier: "NavigationToolbar")
            toolbar.displayMode = .iconOnly
            toolbar.delegate = self
            window.toolbar = toolbar
            window.toolbarStyle = .unified
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Navigation

    func pushViewController(_ vc: NSViewController) {
        navigationStack.append(vc)
        (vc as? ViewController)?.navigator = self
        window?.contentViewController = vc
        if config.fixedContentSize {
            window?.setContentSize(config.windowSize)
        }
        window?.title = vc.title ?? config.defaultTitle
        updateToolbarButtons()
    }

    func popViewController() {
        guard navigationStack.count > 1 else { return }
        let prev = navigationStack[navigationStack.count - 2]
        navigationStack.removeLast()
        window?.contentViewController = prev
        if config.fixedContentSize {
            window?.setContentSize(config.windowSize)
        }
        window?.title = prev.title ?? config.defaultTitle
        updateToolbarButtons()
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.navBack, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.navBack, .flexibleSpace]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .navBack:
            let item = NSToolbarItem(itemIdentifier: .navBack)
            item.label = NSLocalizedString("后退", comment: "")
            item.paletteLabel = NSLocalizedString("后退", comment: "")
            item.toolTip = NSLocalizedString("后退", comment: "")
            let button = NSButton(
                image: NSImage.safeSystemSymbol("chevron.backward"),
                target: self,
                action: #selector(backButtonClicked)
            )
            button.bezelStyle = .texturedRounded
            item.view = button
            item.isEnabled = navigationStack.count > 1
            self.backItem = item
            return item
        default:
            return nil
        }
    }

    // MARK: - Private

    @objc private func backButtonClicked() {
        popViewController()
    }

    private func updateToolbarButtons() {
        backItem?.isEnabled = navigationStack.count > 1
    }
}
