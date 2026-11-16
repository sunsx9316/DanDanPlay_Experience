//
//  MainSearchSectionViewController.swift
//  AniXPlayer
//
//  macOS：主窗口「搜索」分区，包含资源搜索与番剧搜索两个子页面。
//

import Cocoa
import SnapKit

enum MainSearchPage: Int, CaseIterable {
    case resource
    case bangumi

    var title: String {
        switch self {
        case .resource: return NSLocalizedString("资源搜索", comment: "")
        case .bangumi: return NSLocalizedString("番剧搜索", comment: "")
        }
    }

    var accessibilityKey: String {
        switch self {
        case .resource: return "resource"
        case .bangumi: return "bangumi"
        }
    }
}

final class MainSearchSectionViewController: ViewController {

    var onOpenDetail: ((Int) -> Void)? {
        didSet { bangumiSearchViewController.onOpenDetail = onOpenDetail }
    }

    var onDownloadResource: ((ResourceSearchItem) -> Void)? {
        didSet { resourceSearchViewController.onDownload = onDownloadResource }
    }

    private(set) var selectedPage: MainSearchPage = .resource

    private lazy var resourceSearchViewController: ResourceSearchViewController = {
        let vc = ResourceSearchViewController()
        vc.onDownload = self.onDownloadResource
        return vc
    }()

    private lazy var bangumiSearchViewController: SearchUpgradedViewController = {
        let vc = SearchUpgradedViewController()
        vc.onOpenDetail = self.onOpenDetail
        return vc
    }()

    private var currentChild: NSViewController?
    private var childControllers: [MainSearchPage: NSViewController] = [:]

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 620))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.MainShell.searchRoot)
        showPage(.resource, focusSearch: false)
    }

    // MARK: Public

    func select(_ page: MainSearchPage, focusSearch: Bool = true) {
        _ = view
        showPage(page, focusSearch: focusSearch)
    }

    func applyExternalSearch(_ keyword: String) {
        _ = view
        showPage(.bangumi, focusSearch: false)
        bangumiSearchViewController.applyExternalSearch(keyword)
    }

    /// 详情页等外部入口：指定子页面并自动搜索。
    func applyExternalSearch(_ keyword: String, page: MainSearchPage) {
        _ = view
        showPage(page, focusSearch: false)
        switch page {
        case .resource:
            resourceSearchViewController.applyExternalSearch(keyword)
        case .bangumi:
            bangumiSearchViewController.applyExternalSearch(keyword)
        }
    }

    // MARK: Private

    private func showPage(_ page: MainSearchPage, focusSearch: Bool) {
        let child = childViewController(for: page)
        if currentChild !== child {
            currentChild?.view.isHidden = true
            child.view.isHidden = false
            currentChild = child
        }
        selectedPage = page

        guard focusSearch else { return }
        switch page {
        case .resource:
            resourceSearchViewController.focusSearchField()
        case .bangumi:
            bangumiSearchViewController.focusSearchField()
        }
    }

    private func childViewController(for page: MainSearchPage) -> NSViewController {
        if let cached = childControllers[page] {
            return cached
        }

        let child: NSViewController
        switch page {
        case .resource:
            child = resourceSearchViewController
        case .bangumi:
            child = bangumiSearchViewController
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
