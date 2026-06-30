//
//  MediaLibraryWindowController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa

class MediaLibraryWindowController: NavigationWindowController {

    var onSelectFile: ((File, [File]) -> Void)?

    init() {
        let vc = MediaLibraryViewController()
        let config = NavigationConfiguration(
            windowSize: NSSize(width: 480, height: 560),
            defaultTitle: NSLocalizedString("媒体库", comment: ""),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            hasToolbar: true
        )
        super.init(rootViewController: vc, config: config)
        vc.onSelectFile = { [weak self] file, allFiles in
            self?.onSelectFile?(file, allFiles)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
