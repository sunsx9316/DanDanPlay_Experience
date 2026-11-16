//
//  MainShellSection.swift
//  AniXPlayer
//
//  macOS：主窗口顶部一级导航的分区与二级 pivot。
//

import Foundation

enum MainShellSection: Int, CaseIterable {
    case home
    case search
    case library
    case download
    case account

    /// 顶部一级导航。首页由左侧「AniXPlayer」品牌区承担，不再重复显示。
    static let primaryNavigation: [MainShellSection] = [.search, .library, .download, .account]

    var title: String {
        switch self {
        case .home: return NSLocalizedString("首页", comment: "")
        case .search: return NSLocalizedString("搜索", comment: "")
        case .library: return NSLocalizedString("媒体库", comment: "")
        case .download: return NSLocalizedString("下载", comment: "")
        case .account: return NSLocalizedString("我的", comment: "")
        }
    }

    var accessibilityID: String {
        switch self {
        case .home: return AccessibilityID.MainShell.navHome
        case .search: return AccessibilityID.MainShell.navSearch
        case .library: return AccessibilityID.MainShell.navLibrary
        case .download: return AccessibilityID.MainShell.navDownload
        case .account: return AccessibilityID.MainShell.navAccount
        }
    }
}

/// 顶部二级 pivot。不同一级分区有各自的子页面。
enum MainShellPivot: Hashable {
    case home(WelcomeShellPage)
    case search(MainSearchPage)
    case account(MainAccountPage)

    var title: String {
        switch self {
        case .home(let page):
            return page.mainShellPivotTitle
        case .search(let page):
            return page.title
        case .account(let page):
            return page.title
        }
    }

    var accessibilityID: String {
        switch self {
        case .home(let page):
            // 保留首页原有 AX 标识，避免已有脚本失效。
            return "\(AccessibilityID.MainShell.pivotPrefix)\(page.mainShellKey)"
        case .search(let page):
            return "\(AccessibilityID.MainShell.pivotPrefix)search.\(page.accessibilityKey)"
        case .account(let page):
            return "\(AccessibilityID.MainShell.pivotPrefix)account.\(page.accessibilityKey)"
        }
    }
}

extension WelcomeShellPage {
    /// 首页 pivot 第一项在 Windows 版里叫「首页」，而不是「概览」。
    var mainShellPivotTitle: String {
        return self == .overview ? NSLocalizedString("首页", comment: "") : title
    }

    var mainShellKey: String {
        switch self {
        case .overview: return "overview"
        case .announcement: return "announcement"
        case .queue: return "queue"
        case .schedule: return "schedule"
        case .trending: return "trending"
        case .recent: return "recent"
        case .online: return "online"
        }
    }
}
