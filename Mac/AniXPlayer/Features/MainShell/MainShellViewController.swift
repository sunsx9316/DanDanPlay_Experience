//
//  MainShellViewController.swift
//  AniXPlayer
//
//  macOS：主窗口一体化外壳（深色一级导航 + 首页 pivot + 内容区）。
//

import Cocoa
import SnapKit

final class MainShellViewController: ViewController {

    // MARK: Callbacks

    var onOpenFiles: (([File], File?) -> Void)?
    var onResumeFiles: (([File], File?, Double) -> Void)?
    var onOpenNetworkFile: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowMembership: (() -> Void)?
    var onPlayFiles: (([File], File) -> Void)?

    // MARK: Views

    private let topBar = MainTopBarView()
    private let contentHost = NSView()
    private var topBarHeightConstraint: Constraint?

    private lazy var rootView: MainShellRootView = {
        let view = MainShellRootView(frame: NSRect(x: 0, y: 0, width: 1100, height: 720))
        view.onAppearanceChange = { [weak self] in
            self?.updateBackgroundColors()
        }
        return view
    }()

    // MARK: State

    private var currentSection: MainShellSection = .home
    private var currentChild: NSViewController?
    private var sectionChildren: [MainShellSection: NSViewController] = [:]
    private var libraryViewController: LocalLibraryViewController?
    private var downloadViewController: DownloadViewController?
    private var searchSectionViewController: MainSearchSectionViewController?
    private var accountSectionViewController: MainAccountSectionViewController?
    private var didApplyWindowChrome = false
    private var didObserveWindowClose = false

    private lazy var homeViewController: WelcomeShellViewController = {
        let vc = WelcomeShellViewController(showsSidebar: false, managesWindowSize: false)
        vc.onOpenFiles = { [weak self] files, startFile in
            self?.onOpenFiles?(files, startFile)
        }
        vc.onResumeFiles = { [weak self] files, startFile, progress in
            self?.onResumeFiles?(files, startFile, progress)
        }
        vc.onOpenNetworkFile = { [weak self] in
            self?.onOpenNetworkFile?()
        }
        vc.onShowSettings = { [weak self] in
            self?.onShowSettings?()
        }
        vc.onShowMembership = { [weak self] in
            self?.onShowMembership?()
        }
        vc.onPageChange = { [weak self] _ in
            guard let self = self, self.currentSection == .home else { return }
            self.syncPivotSelection()
        }
        return vc
    }()

    // MARK: Lifecycle

    override func loadView() {
        self.view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = AppInfoHelper.appDisplayName
        view.setAccessibilityIdentifier(AccessibilityID.MainShell.root)
        contentHost.wantsLayer = true
        updateBackgroundColors()

        topBar.onSelectSection = { [weak self] section in
            self?.handlePrimarySelection(section)
        }
        topBar.onSelectPivot = { [weak self] pivot in
            self?.handlePivotSelection(pivot)
        }
        topBar.onLogin = { [weak self] in
            self?.startLogin()
        }
        topBar.onShowMembership = { [weak self] in
            self?.onShowMembership?()
        }
        topBar.onShowSettings = { [weak self] in
            self?.onShowSettings?()
        }

        view.addSubview(topBar)
        view.addSubview(contentHost)

        topBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            topBarHeightConstraint = make.height.equalTo(topBar.preferredHeight).constraint
        }
        contentHost.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loginStateChanged),
            name: .AnixUserLoginStateDidChange,
            object: nil
        )

        showSection(.home)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyWindowChromeIfNeeded()
        observeWindowCloseIfNeeded()
        refreshSession()
    }

    // MARK: Public

    /// 从菜单、AppDelegate 或内部入口切换一级分区；保留各分区已有状态。
    func select(_ section: MainShellSection) {
        _ = view
        showSection(section)
    }

    func selectHomePage(_ page: WelcomeShellPage) {
        _ = view
        showSection(.home)
        homeViewController.selectPage(page)
    }

    /// 详情页「搜索资源」入口：切换到资源搜索子页并自动搜索。
    func openResourceSearch(keyword: String) {
        _ = view
        select(.search)
        searchSectionViewController?.applyExternalSearch(keyword, page: .resource)
        syncPivotSelection()
    }

    /// 详情页「在线观看」入口：切换到首页在线观看并自动搜索。
    func openOnlineSearch(keyword: String) {
        _ = view
        select(.home)
        homeViewController.selectPage(.online)
        homeViewController.applyExternalOnlineSearch(keyword)
        syncPivotSelection()
    }

    // MARK: Section switching

    private func handlePrimarySelection(_ section: MainShellSection) {
        switch section {
        case .home:
            if currentSection == .home {
                homeViewController.selectPage(.overview)
            } else {
                select(.home)
            }
        case .search:
            if currentSection == .search {
                // 再次点击「搜索」回到第一个子页面：资源搜索。
                searchSectionViewController?.select(.resource)
                syncPivotSelection()
            } else {
                select(.search)
            }
        case .account:
            if currentSection == .account {
                accountSectionViewController?.select(.overview)
            } else {
                select(.account)
            }
        case .library, .download:
            select(section)
        }
    }

    private func handlePivotSelection(_ pivot: MainShellPivot) {
        switch pivot {
        case .home(let page):
            select(.home)
            homeViewController.selectPage(page)
            syncPivotSelection()
        case .search(let page):
            select(.search)
            searchSectionViewController?.select(page)
            syncPivotSelection()
        case .account(let page):
            select(.account)
            accountSectionViewController?.select(page)
            syncPivotSelection()
        }
    }

    private func showSection(_ section: MainShellSection) {
        let child = childViewController(for: section)
        if currentChild !== child {
            currentChild?.view.isHidden = true
            child.view.isHidden = false
            currentChild = child
        }
        currentSection = section

        topBar.setSelectedSection(section)
        configurePivot(for: section)

        if section == .account {
            accountSectionViewController?.refreshSession()
        }
    }

    private func configurePivot(for section: MainShellSection) {
        let items: [MainShellPivot]
        let selected: MainShellPivot

        switch section {
        case .home:
            items = WelcomeShellPage.allCases.map(MainShellPivot.home)
            selected = .home(homeViewController.selectedPage)
        case .search:
            items = MainSearchPage.allCases.map(MainShellPivot.search)
            selected = .search(searchSectionViewController?.selectedPage ?? .resource)
        case .account:
            items = MainAccountPage.allCases.map(MainShellPivot.account)
            selected = .account(accountSectionViewController?.selectedPage ?? .overview)
        case .library, .download:
            topBar.setPivotVisible(false)
            topBarHeightConstraint?.update(offset: topBar.preferredHeight)
            view.needsLayout = true
            return
        }

        topBar.setPivot(items, selected: selected)
        topBar.setPivotVisible(true)
        topBarHeightConstraint?.update(offset: topBar.preferredHeight)
        view.needsLayout = true
    }

    private func syncPivotSelection() {
        switch currentSection {
        case .home:
            topBar.setSelectedPivot(.home(homeViewController.selectedPage))
        case .search:
            topBar.setSelectedPivot(.search(searchSectionViewController?.selectedPage ?? .resource))
        case .account:
            topBar.setSelectedPivot(.account(accountSectionViewController?.selectedPage ?? .overview))
        case .library, .download:
            break
        }
    }

    private func childViewController(for section: MainShellSection) -> NSViewController {
        if let cached = sectionChildren[section] {
            return cached
        }

        let child: NSViewController
        switch section {
        case .home:
            child = homeViewController
        case .search:
            let vc = MainSearchSectionViewController()
            vc.onOpenDetail = { [weak self] animeId in
                self?.openDetail(animeId: animeId)
            }
            vc.onDownloadResource = { [weak self] item in
                self?.openResourceDownload(item)
            }
            searchSectionViewController = vc
            child = vc
        case .library:
            let store: LocalLibraryStore?
            let storeError: Error?
            do {
                store = try LocalLibraryStore()
                storeError = nil
            } catch {
                store = nil
                storeError = error
            }
            let vc = LocalLibraryViewController(store: store, storeError: storeError)
            vc.onPlayFiles = { [weak self] files, startFile in
                self?.onPlayFiles?(files, startFile)
            }
            libraryViewController = vc
            child = vc
        case .download:
            let vc = DownloadViewController(manager: .shared)
            vc.onPlayFiles = { [weak self] files, startFile in
                self?.onPlayFiles?(files, startFile)
            }
            downloadViewController = vc
            child = vc
        case .account:
            let vc = MainAccountSectionViewController()
            vc.onShowMembership = { [weak self] in
                self?.onShowMembership?()
            }
            vc.onShowSettings = { [weak self] in
                self?.onShowSettings?()
            }
            vc.onOpenDetail = { [weak self] animeId in
                self?.openDetail(animeId: animeId)
            }
            vc.onPageChange = { [weak self] _ in
                self?.syncPivotSelection()
            }
            accountSectionViewController = vc
            child = vc
        }

        sectionChildren[section] = child
        addChild(child)
        contentHost.addSubview(child.view)
        child.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        child.view.isHidden = true
        return child
    }

    // MARK: Search

    private func performGlobalSearch(_ keyword: String) {
        select(.search)
        if keyword.isEmpty {
            searchSectionViewController?.select(.bangumi)
        } else {
            searchSectionViewController?.applyExternalSearch(keyword)
        }
        syncPivotSelection()
    }

    private func openResourceDownload(_ item: ResourceSearchItem) {
        guard let source = item.downloadSource else { return }
        select(.download)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let download = self.downloadViewController else { return }
            download.openAddSheet(prefillSource: source)
        }
    }

    private func openDetail(animeId: Int) {
        WelcomeDetailPresenter.shared.open(animeId: animeId, presenting: view.window)
    }

    // MARK: Session

    private func startLogin() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            _ = await LoginGate.shared.ensureLoggedIn(presenting: self.view.window)
            self.refreshSession()
        }
    }

    private func refreshSession() {
        let session = SessionStore.shared
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let isLoggedIn = await session.isLoggedIn()
            let profile = await session.currentProfile()
            self.topBar.updateSession(isLoggedIn: isLoggedIn, profile: profile)
            self.accountSectionViewController?.updateSession(isLoggedIn: isLoggedIn, profile: profile)
        }
    }

    @objc private func loginStateChanged() {
        refreshSession()
    }

    // MARK: Window

    private func applyWindowChromeIfNeeded() {
        guard !didApplyWindowChrome, let window = view.window else { return }
        didApplyWindowChrome = true

        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = MainShellPalette.bar
        window.contentMinSize = NSSize(width: 1000, height: 680)

        // 首次打开/旧版保存的窗口可能偏小；恢复到欢迎页原来的默认宽度。
        let contentSize = window.contentLayoutRect.size
        if contentSize.width < 1100 || contentSize.height < 720 {
            window.setContentSize(NSSize(
                width: max(contentSize.width, 1100),
                height: max(contentSize.height, 720)
            ))
        }
    }

    private func observeWindowCloseIfNeeded() {
        guard !didObserveWindowClose, let window = view.window else { return }
        didObserveWindowClose = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    @objc private func mainWindowWillClose() {
        // 只停止媒体库扫描/匹配；下载任务继续在后台运行。
        libraryViewController?.cancelOperations()
    }

    // MARK: Appearance

    private func updateBackgroundColors() {
        rootView.effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }
            let background = NSColor.windowBackgroundColor.cgColor
            self.rootView.layer?.backgroundColor = background
            self.contentHost.layer?.backgroundColor = background
        }
    }
}

// MARK: - Root view

private final class MainShellRootView: NSView {

    var onAppearanceChange: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}
