//
//  DownloadWindowController.swift
//  AniXPlayer
//
//  macOS：下载中心窗口。
//

import Cocoa

final class DownloadWindowController: NavigationWindowController {

    /// 由 AppDelegate 注入，使用现有独立播放器窗口播放。
    var onPlayFiles: (([File], File) -> Void)? {
        didSet {
            downloadViewController.onPlayFiles = onPlayFiles
        }
    }

    private let downloadViewController: DownloadViewController

    init(manager: DownloadManager = .shared) {
        downloadViewController = DownloadViewController(manager: manager)

        let config = NavigationConfiguration(
            windowSize: NSSize(width: 1000, height: 640),
            defaultTitle: NSLocalizedString("下载中心", comment: ""),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            hasToolbar: false,
            fixedContentSize: false
        )
        super.init(rootViewController: downloadViewController, config: config)

        window?.title = NSLocalizedString("下载中心", comment: "")
        window?.setAccessibilityIdentifier(AccessibilityID.Download.window)
        window?.minSize = NSSize(width: 880, height: 580)

        downloadViewController.onPlayFiles = { [weak self] files, start in
            self?.onPlayFiles?(files, start)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func presentAddSheet(prefillSource: String?) {
        _ = downloadViewController.view
        downloadViewController.openAddSheet(prefillSource: prefillSource)
    }

    func presentAddSheet(prefillSources: [String]) {
        _ = downloadViewController.view
        downloadViewController.enqueuePrefillSources(prefillSources)
    }

    func revealTask(id: UUID) {
        _ = downloadViewController.view
        downloadViewController.revealTask(id: id)
    }

    override func windowWillClose(_ notification: Notification) {
        super.windowWillClose(notification)
    }
}
