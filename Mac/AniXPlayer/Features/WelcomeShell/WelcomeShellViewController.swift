//
//  WelcomeShellViewController.swift
//  AniXPlayer
//
//  macOS：Windows 式欢迎页外壳（左侧导航 + 右侧内容）。
//

import Cocoa
import SnapKit

// MARK: - Page

enum WelcomeShellPage: Int, CaseIterable {
    case overview
    case announcement
    case queue
    case schedule
    case trending
    case recent
    case online

    var title: String {
        switch self {
        case .overview: return NSLocalizedString("首页", comment: "")
        case .announcement: return NSLocalizedString("公告", comment: "")
        case .queue: return NSLocalizedString("未看番剧", comment: "")
        case .schedule: return NSLocalizedString("新番时间表", comment: "")
        case .trending: return NSLocalizedString("排行榜", comment: "")
        case .recent: return NSLocalizedString("继续播放", comment: "")
        case .online: return NSLocalizedString("在线观看", comment: "")
        }
    }

    var symbolName: String {
        switch self {
        case .overview: return "house"
        case .announcement: return "megaphone"
        case .queue: return "tv"
        case .schedule: return "calendar"
        case .trending: return "flame"
        case .recent: return "clock.arrow.circlepath"
        case .online: return "play.rectangle.on.rectangle"
        }
    }

    var accessibilityID: String {
        switch self {
        case .overview: return AccessibilityID.WelcomeShell.navHome
        case .announcement: return AccessibilityID.WelcomeShell.navAnnouncement
        case .queue: return AccessibilityID.WelcomeShell.navQueue
        case .schedule: return AccessibilityID.WelcomeShell.navSchedule
        case .trending: return AccessibilityID.WelcomeShell.navTrending
        case .recent: return AccessibilityID.WelcomeShell.navRecent
        case .online: return AccessibilityID.WelcomeShell.navOnline
        }
    }
}

// MARK: - Routing

@MainActor
protocol WelcomeShellRouting: AnyObject {
    func showPage(_ page: WelcomeShellPage)
    func showSchedule(searchText: String?)
    func openDetail(animeId: Int)
    func openLocalFiles()
    func openRemoteFiles()
    func openPlayerPlaylist()
    func openQueueWindow()
    func play(files: [File], startWith startFile: File?, progress: Double?)
}

extension WelcomeShellRouting {
    func play(files: [File], startWith startFile: File?) {
        play(files: files, startWith: startFile, progress: nil)
    }
}

@MainActor
protocol WelcomeShellLoginAware: AnyObject {
    func welcomeShellLoginStateDidChange()
}

// MARK: - Shell

final class WelcomeShellViewController: ViewController {

    // MARK: Callbacks（保持 PlayerLaunchViewController 原有语义）

    var onOpenFiles: (([File], File?) -> Void)?
    var onResumeFiles: (([File], File?, Double) -> Void)?
    var onOpenNetworkFile: (() -> Void)?
    var onOpenPlayerPlaylist: (() -> Void)?
    var onShowHomePage: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowMembership: (() -> Void)?
    /// 页面因内部路由（例如“查看时间表”）变化时同步给嵌入方。
    var onPageChange: ((WelcomeShellPage) -> Void)?

    // MARK: Views

    private let showsSidebar: Bool
    private let managesWindowSize: Bool
    private let sidebar = WelcomeShellSidebarView()
    private let contentContainer = NSView()
    private var currentChild: NSViewController?
    private(set) var selectedPage: WelcomeShellPage = .overview
    private var didApplyWindowMinimum = false

    private lazy var rootView: WelcomeShellRootView = {
        let view = WelcomeShellRootView(frame: NSRect(x: 0, y: 0, width: 1100, height: 720))
        view.onAppearanceChange = { [weak self] in
            self?.updateBackgroundColors()
        }
        return view
    }()

    // MARK: Lifecycle

    init(showsSidebar: Bool = true, managesWindowSize: Bool = true) {
        self.showsSidebar = showsSidebar
        self.managesWindowSize = managesWindowSize
        super.init()
    }

    required init?(coder: NSCoder) {
        self.showsSidebar = true
        self.managesWindowSize = true
        super.init(coder: coder)
    }

    override func loadView() {
        self.view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = AppInfoHelper.appDisplayName
        view.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.root)
        updateBackgroundColors()

        sidebar.onSelectPage = { [weak self] page in
            self?.selectPage(page)
        }
        sidebar.onLogin = { [weak self] in
            self?.startLogin()
        }
        sidebar.onMembership = { [weak self] in
            self?.onShowMembership?()
        }
        sidebar.onSettings = { [weak self] in
            self?.onShowSettings?()
        }

        contentContainer.wantsLayer = true
        if showsSidebar {
            view.addSubview(sidebar)
            view.addSubview(contentContainer)

            sidebar.snp.makeConstraints { make in
                make.top.leading.bottom.equalToSuperview()
                make.width.equalTo(200)
            }
            contentContainer.snp.makeConstraints { make in
                make.top.trailing.bottom.equalToSuperview()
                make.leading.equalTo(sidebar.snp.trailing).offset(1)
            }
        } else {
            view.addSubview(contentContainer)
            contentContainer.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loginStateChanged),
            name: .AnixUserLoginStateDidChange,
            object: nil
        )

        selectPage(.overview)
        refreshSidebarSession()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshSidebarSession()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        guard managesWindowSize, !didApplyWindowMinimum, let window = self.view.window else { return }
        didApplyWindowMinimum = true

        window.contentMinSize = NSSize(width: 900, height: 620)
        let contentSize = window.contentLayoutRect.size
        if contentSize.width < 1100 || contentSize.height < 720 {
            window.setContentSize(NSSize(
                width: max(contentSize.width, 1100),
                height: max(contentSize.height, 720)
            ))
        }
    }

    // MARK: Public

    func presentLocalFilePicker() {
        openLocalFiles()
    }

    func selectPage(_ page: WelcomeShellPage, scheduleSearchText: String? = nil) {
        showPage(page, scheduleSearchText: scheduleSearchText)
    }

    // MARK: Private - pages

    private func showPage(_ page: WelcomeShellPage, scheduleSearchText: String? = nil) {
        let samePage = selectedPage == page && currentChild != nil
        if samePage {
            if let schedule = currentChild as? WelcomeScheduleViewController,
               let searchText = scheduleSearchText {
                schedule.applyExternalSearch(searchText)
            }
            if showsSidebar {
                sidebar.select(page)
            }
            onPageChange?(page)
            return
        }

        currentChild?.view.removeFromSuperview()
        currentChild?.removeFromParent()
        currentChild = nil

        let vc = makePageViewController(page, scheduleSearchText: scheduleSearchText)
        addChild(vc)
        contentContainer.addSubview(vc.view)
        vc.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        currentChild = vc
        selectedPage = page
        if showsSidebar {
            sidebar.select(page)
        }
        title = AppInfoHelper.appDisplayName
        onPageChange?(page)

        if let scrollPage = vc as? WelcomeShellScrollPageViewController {
            scrollPage.scrollToTop()
            DispatchQueue.main.async {
                scrollPage.scrollToTop()
            }
        }
    }

    private func makePageViewController(
        _ page: WelcomeShellPage,
        scheduleSearchText: String?
    ) -> NSViewController {
        switch page {
        case .overview:
            let vc = WelcomeOverviewViewController()
            vc.router = self
            return vc
        case .announcement:
            let vc = WelcomeAnnouncementViewController()
            vc.router = self
            return vc
        case .queue:
            let vc = WelcomeQueueViewController()
            vc.router = self
            return vc
        case .schedule:
            let vc = WelcomeScheduleViewController(initialSearchText: scheduleSearchText)
            vc.router = self
            return vc
        case .trending:
            let vc = WelcomeTrendingPageViewController()
            vc.router = self
            return vc
        case .recent:
            let vc = WelcomeRecentViewController()
            vc.router = self
            return vc
        case .online:
            let vc = WelcomeOnlineViewController()
            vc.router = self
            return vc
        }
    }

    // MARK: Private - session

    private func refreshSidebarSession() {
        guard showsSidebar else { return }
        let session = SessionStore.shared
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let isLoggedIn = await session.isLoggedIn()
            let userProfile = await session.currentProfile()
            self.sidebar.updateSession(isLoggedIn: isLoggedIn, profile: userProfile)
        }
    }

    private func startLogin() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            _ = await LoginGate.shared.ensureLoggedIn(presenting: self.view.window)
            self.refreshSidebarSession()
        }
    }

    @objc private func loginStateChanged() {
        refreshSidebarSession()
        if let child = currentChild as? WelcomeShellLoginAware {
            child.welcomeShellLoginStateDidChange()
        }
    }

    // MARK: Private - appearance

    private func updateBackgroundColors() {
        rootView.effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }
            self.rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            self.contentContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }
}

// MARK: - Routing

extension WelcomeShellViewController: WelcomeShellRouting {
    func showPage(_ page: WelcomeShellPage) {
        showPage(page, scheduleSearchText: nil)
    }

    func showSchedule(searchText: String?) {
        showPage(.schedule, scheduleSearchText: searchText)
    }

    func openDetail(animeId: Int) {
        WelcomeDetailPresenter.shared.open(animeId: animeId, presenting: view.window)
    }

    func openLocalFiles() {
        LocalFile.fileManager.pickFiles(LocalFile.rootFile, from: self, filterType: .all) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let files):
                let mediaFiles = files.filter { !$0.url.isSubtitleFile && !$0.url.isDanmakuFile }
                guard !mediaFiles.isEmpty else {
                    self.view.show(text: NSLocalizedString("请先打开视频文件", comment: ""))
                    return
                }
                self.onOpenFiles?(mediaFiles, nil)
            case .failure:
                break
            }
        }
    }

    func openRemoteFiles() {
        onOpenNetworkFile?()
    }

    func openPlayerPlaylist() {
        onOpenPlayerPlaylist?()
    }

    func openQueueWindow() {
        WelcomeQueueWindowPresenter.shared.open(presenting: view.window)
    }

    func play(files: [File], startWith startFile: File?, progress: Double?) {
        if let progress = progress, let onResumeFiles = onResumeFiles {
            onResumeFiles(files, startFile, progress)
        } else {
            onOpenFiles?(files, startFile)
        }
    }
}

// MARK: - Root view

final class WelcomeShellRootView: NSView {

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
