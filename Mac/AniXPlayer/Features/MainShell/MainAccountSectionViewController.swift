//
//  MainAccountSectionViewController.swift
//  AniXPlayer
//
//  macOS：主窗口「我的」分区，包含账号概览与播放历史。
//

import Cocoa
import SnapKit

enum MainAccountPage: Int, CaseIterable {
    case overview
    case history

    var title: String {
        switch self {
        case .overview: return NSLocalizedString("概览", comment: "")
        case .history: return NSLocalizedString("播放历史", comment: "")
        }
    }

    var accessibilityKey: String {
        switch self {
        case .overview: return "overview"
        case .history: return "history"
        }
    }
}

final class MainAccountSectionViewController: ViewController {

    var onShowMembership: (() -> Void)? {
        didSet { hubViewController.onShowMembership = onShowMembership }
    }

    var onShowSettings: (() -> Void)? {
        didSet { hubViewController.onShowSettings = onShowSettings }
    }

    var onOpenDetail: ((Int) -> Void)? {
        didSet { historyViewController.onOpenDetail = onOpenDetail }
    }

    var onPageChange: ((MainAccountPage) -> Void)?

    private(set) var selectedPage: MainAccountPage = .overview

    private lazy var hubViewController: MainAccountHubViewController = {
        let vc = MainAccountHubViewController()
        vc.onShowHistory = { [weak self] in
            self?.select(.history)
        }
        vc.onShowMembership = self.onShowMembership
        vc.onShowSettings = self.onShowSettings
        return vc
    }()

    private lazy var historyViewController: PlayHistoryViewController = {
        let vc = PlayHistoryViewController()
        vc.onOpenDetail = self.onOpenDetail
        return vc
    }()

    private var currentChild: NSViewController?
    private var childControllers: [MainAccountPage: NSViewController] = [:]

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 620))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.MainShell.accountRoot)
        showPage(.overview, refresh: false)
    }

    // MARK: Public

    func select(_ page: MainAccountPage) {
        _ = view
        showPage(page, refresh: true)
        onPageChange?(page)
    }

    func updateSession(isLoggedIn: Bool, profile: OAuthUserProfile?) {
        hubViewController.updateSession(isLoggedIn: isLoggedIn, profile: profile)
    }

    func refreshSession() {
        hubViewController.refreshSession()
    }

    // MARK: Private

    private func showPage(_ page: MainAccountPage, refresh: Bool) {
        let isNewChild = childControllers[page] == nil
        let child = childViewController(for: page)
        if currentChild !== child {
            currentChild?.view.isHidden = true
            child.view.isHidden = false
            currentChild = child
        }
        selectedPage = page

        guard refresh, !isNewChild else { return }
        switch page {
        case .overview:
            hubViewController.refreshSession()
        case .history:
            historyViewController.refreshContent()
        }
    }

    private func childViewController(for page: MainAccountPage) -> NSViewController {
        if let cached = childControllers[page] {
            return cached
        }

        let child: NSViewController
        switch page {
        case .overview:
            child = hubViewController
        case .history:
            child = historyViewController
        }

        childControllers[page] = child
        addChild(child)
        view.addSubview(child.view)
        child.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        child.view.isHidden = true
        return child
    }
}
