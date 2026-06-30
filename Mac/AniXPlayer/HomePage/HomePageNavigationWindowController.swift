//
//  HomePageNavigationWindowController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa

class HomePageNavigationWindowController: NavigationWindowController {

    init(rootViewController: NSViewController) {
        let config = NavigationConfiguration(
            windowSize: NSSize(width: 490, height: 844),
            defaultTitle: NSLocalizedString("主页", comment: ""),
            styleMask: [.titled, .closable, .miniaturizable],
            hasToolbar: true,
            fixedContentSize: true
        )
        super.init(rootViewController: rootViewController, config: config)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
