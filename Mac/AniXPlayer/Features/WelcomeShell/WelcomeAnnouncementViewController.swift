//
//  WelcomeAnnouncementViewController.swift
//  AniXPlayer
//
//  macOS：欢迎页公告列表。
//

import Cocoa
import SnapKit

final class WelcomeAnnouncementViewController: WelcomeShellScrollPageViewController, WelcomeShellLoginAware {

    weak var router: WelcomeShellRouting?

    private let service = HomePageService()
    private var banners: [BannerPageItem] = []
    private var loadTask: Task<Void, Never>?
    private var isLoggedIn = false

    private lazy var headerView: WelcomeShellPageHeaderView = {
        let view = WelcomeShellPageHeaderView(
            title: NSLocalizedString("公告", comment: ""),
            subtitle: NSLocalizedString("来自弹弹play的最新消息", comment: "")
        )
        let refreshButton = WelcomeShellClosureButton(
            image: welcomeShellSymbol("arrow.clockwise", pointSize: 12, weight: .semibold)
        )
        refreshButton.isBordered = false
        refreshButton.contentTintColor = .mainColor
        refreshButton.toolTip = NSLocalizedString("刷新公告", comment: "")
        refreshButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.announcementRefresh)
        refreshButton.onClick = { [weak self] in
            self?.load()
        }
        view.trailingStack.addArrangedSubview(refreshButton)
        return view
    }()

    private let stateView = WelcomeShellStateView()
    private let listStack = NSStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.announcementRoot)
        title = NSLocalizedString("公告", comment: "")

        listStack.orientation = .vertical
        listStack.alignment = .width
        listStack.spacing = 10
        listStack.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.announcementList)

        stateView.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.announcementStatus)
        addFullWidth(headerView, spacingAfter: 4)
        addFullWidth(stateView)
        addFullWidth(listStack)

        load()
    }

    deinit {
        loadTask?.cancel()
    }

    private func load() {
        loadTask?.cancel()
        stateView.configure(title: NSLocalizedString("正在加载公告…", comment: ""))
        listStack.isHidden = true

        loadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard AccessTokenHolder.shared.current() != nil else {
                self.isLoggedIn = false
                self.applyLoggedOutState()
                return
            }
            self.isLoggedIn = true

            do {
                let homepage = try await self.service.loadHomepage()
                guard !Task.isCancelled else { return }
                self.banners = homepage.banners
                self.rebuildList()
            } catch {
                guard !Task.isCancelled else { return }
                self.banners = []
                self.listStack.isHidden = true
                self.stateView.isHidden = false
                self.stateView.configure(
                    title: NSLocalizedString("公告加载失败", comment: ""),
                    detail: error.localizedDescription,
                    actionTitle: NSLocalizedString("重试", comment: ""),
                    onAction: { [weak self] in
                        self?.load()
                    }
                )
                self.layoutContent()
            }
        }
    }

    private func rebuildList() {
        listStack.arrangedSubviews.forEach {
            listStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !banners.isEmpty else {
            listStack.isHidden = true
            stateView.isHidden = false
            stateView.configure(title: NSLocalizedString("暂无公告", comment: ""))
            layoutContent()
            return
        }

        stateView.isHidden = true
        listStack.isHidden = false

        for banner in banners {
            let card = WelcomeShellAnnouncementCardView()
            card.configure(with: banner)
            card.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.announcementItemPrefix)\(banner.id)")
            card.onClick = {
                guard let url = URL(string: banner.url), !banner.url.isEmpty else { return }
                NSWorkspace.shared.open(url)
            }
            listStack.addArrangedSubview(card)
            card.snp.makeConstraints { make in
                make.width.equalTo(listStack)
            }
        }
        layoutContent()
    }

    private func applyLoggedOutState() {
        listStack.isHidden = true
        stateView.isHidden = false
        stateView.configure(
            title: NSLocalizedString("登录后查看公告", comment: ""),
            detail: NSLocalizedString("公告来自弹弹play账号服务", comment: ""),
            actionTitle: NSLocalizedString("登录", comment: ""),
            onAction: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    _ = await LoginGate.shared.ensureLoggedIn(presenting: self.view.window)
                }
            }
        )
        layoutContent()
    }

    func welcomeShellLoginStateDidChange() {
        load()
    }
}
