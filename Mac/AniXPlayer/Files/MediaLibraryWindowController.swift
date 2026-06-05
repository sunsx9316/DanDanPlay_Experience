//
//  MediaLibraryWindowController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa

protocol MediaLibraryNavigation: AnyObject {
    func pushViewController(_ vc: NSViewController)
    func popViewController()
}

class MediaLibraryWindowController: NSWindowController, MediaLibraryNavigation {

    private var navigationStack: [NSViewController] = []

    var onSelectFile: ((File, [File]) -> Void)?

    private let defaultTitle = NSLocalizedString("媒体库", comment: "")

    private lazy var mediaLibraryVC: MediaLibraryViewController = {
        let vc = MediaLibraryViewController()
        vc.navigator = self
        vc.onSelectFile = { [weak self] file, allFiles in
            self?.onSelectFile?(file, allFiles)
        }
        return vc
    }()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = defaultTitle
        window.center()
        super.init(window: window)

        navigationStack.append(mediaLibraryVC)
        window.contentViewController = mediaLibraryVC
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - MediaLibraryNavigation

    func pushViewController(_ vc: NSViewController) {
        navigationStack.append(vc)
        window?.contentViewController = vc
        window?.title = vc.title ?? defaultTitle
    }

    func popViewController() {
        guard navigationStack.count > 1 else { return }
        navigationStack.removeLast()
        let prev = navigationStack.last!
        window?.contentViewController = prev
        window?.title = prev.title ?? defaultTitle
    }
}
