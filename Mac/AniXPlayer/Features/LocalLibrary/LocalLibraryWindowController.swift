//
//  LocalLibraryWindowController.swift
//  AniXPlayer
//
//  macOS：本地媒体库窗口（与远程文件浏览 MediaLibraryWindowController 区分）。
//

import Cocoa

final class LocalLibraryWindowController: NavigationWindowController {

    /// 由 AppDelegate/MainViewController 注入，使用现有独立播放器窗口播放。
    var onPlayFiles: (([File], File) -> Void)? {
        didSet {
            localLibraryViewController.onPlayFiles = onPlayFiles
        }
    }

    private let localLibraryViewController: LocalLibraryViewController

    init() {
        let store: LocalLibraryStore?
        let storeError: Error?
        do {
            store = try LocalLibraryStore()
            storeError = nil
        } catch {
            store = nil
            storeError = error
        }

        localLibraryViewController = LocalLibraryViewController(
            store: store,
            storeError: storeError
        )

        let config = NavigationConfiguration(
            windowSize: NSSize(width: 1100, height: 720),
            defaultTitle: NSLocalizedString("本地媒体库", comment: ""),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            hasToolbar: false,
            fixedContentSize: false
        )
        super.init(rootViewController: localLibraryViewController, config: config)

        window?.title = NSLocalizedString("本地媒体库", comment: "")
        window?.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.window)
        window?.minSize = NSSize(width: 860, height: 560)

        localLibraryViewController.onPlayFiles = { [weak self] files, start in
            self?.onPlayFiles?(files, start)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowWillClose(_ notification: Notification) {
        localLibraryViewController.cancelOperations()
        super.windowWillClose(notification)
    }
}
