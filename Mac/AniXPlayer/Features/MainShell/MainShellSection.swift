//
//  MainShellSection.swift
//  AniXPlayer
//
//  macOS：主窗口顶部一级导航的分区。
//

import Foundation

enum MainShellSection: Int, CaseIterable {
    case home
    case search
    case library
    case download
    case history
    case account

    var title: String {
        switch self {
        case .home: return NSLocalizedString("首页", comment: "")
        case .search: return NSLocalizedString("搜索", comment: "")
        case .library: return NSLocalizedString("媒体库", comment: "")
        case .download: return NSLocalizedString("下载", comment: "")
        case .history: return NSLocalizedString("历史", comment: "")
        case .account: return NSLocalizedString("我的", comment: "")
        }
    }

    var accessibilityID: String {
        switch self {
        case .home: return AccessibilityID.MainShell.navHome
        case .search: return AccessibilityID.MainShell.navSearch
        case .library: return AccessibilityID.MainShell.navLibrary
        case .download: return AccessibilityID.MainShell.navDownload
        case .history: return AccessibilityID.MainShell.navHistory
        case .account: return AccessibilityID.MainShell.navAccount
        }
    }
}
