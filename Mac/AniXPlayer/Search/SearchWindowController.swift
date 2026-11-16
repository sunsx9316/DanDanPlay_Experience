//
//  SearchWindowController.swift
//  AniXPlayer
//
//  macOS：独立搜索窗口（动画 / 剧集 / 标签 / 高级搜索）。
//

import Cocoa

final class SearchWindowController: NavigationWindowController {

    init() {
        let config = NavigationConfiguration(
            windowSize: NSSize(width: 900, height: 640),
            defaultTitle: NSLocalizedString("搜索", comment: ""),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            hasToolbar: true,
            fixedContentSize: false
        )
        super.init(rootViewController: SearchUpgradedViewController(), config: config)

        window?.minSize = NSSize(width: 820, height: 560)
        window?.setAccessibilityIdentifier(AccessibilityID.Search.window)
        window?.setAccessibilityLabel(NSLocalizedString("搜索窗口", comment: ""))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
