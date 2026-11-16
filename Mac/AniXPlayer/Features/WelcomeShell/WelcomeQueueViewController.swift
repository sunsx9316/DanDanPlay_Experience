//
//  WelcomeQueueViewController.swift
//  AniXPlayer
//
//  macOS：欢迎页未看番剧列表（P4 追番队列的简介页）。
//

import Cocoa
import SnapKit

final class WelcomeQueueViewController: WelcomeShellScrollPageViewController, WelcomeShellLoginAware {

    weak var router: WelcomeShellRouting?

    private let service = HomePageService()
    private var items: [WelcomeQueueCardItem] = []
    private var loadTask: Task<Void, Never>?
    private var isLoggedIn = false

    private lazy var headerView: WelcomeShellPageHeaderView = {
        let view = WelcomeShellPageHeaderView(
            title: NSLocalizedString("未看番剧", comment: ""),
            subtitle: NSLocalizedString("追番队列里尚未观看的剧集", comment: "")
        )

        let viewAllButton = WelcomeShellClosureButton(title: NSLocalizedString("查看全部", comment: ""))
        viewAllButton.bezelStyle = .rounded
        viewAllButton.controlSize = .small
        viewAllButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.queuePageViewAll)
        viewAllButton.onClick = { [weak self] in
            self?.router?.openQueueWindow()
        }

        let refreshButton = WelcomeShellClosureButton(
            image: welcomeShellSymbol("arrow.clockwise", pointSize: 12, weight: .semibold)
        )
        refreshButton.isBordered = false
        refreshButton.contentTintColor = .mainColor
        refreshButton.toolTip = NSLocalizedString("刷新未看番剧列表", comment: "")
        refreshButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.queuePageRefresh)
        refreshButton.onClick = { [weak self] in
            self?.load()
        }

        view.trailingStack.addArrangedSubview(viewAllButton)
        view.trailingStack.addArrangedSubview(refreshButton)
        return view
    }()

    private let summaryLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor
    )
    private let stateView = WelcomeShellStateView()
    private let listStack = NSStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.queuePageRoot)
        title = NSLocalizedString("未看番剧", comment: "")

        listStack.orientation = .vertical
        listStack.alignment = .width
        listStack.spacing = 10
        listStack.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.queuePageList)
        stateView.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.queuePageStatus)

        addFullWidth(headerView, spacingAfter: 2)
        addFullWidth(summaryLabel, spacingAfter: 2)
        addFullWidth(stateView)
        addFullWidth(listStack)

        load()
    }

    deinit {
        loadTask?.cancel()
    }

    private func load() {
        loadTask?.cancel()
        stateView.configure(title: NSLocalizedString("正在加载未看番剧…", comment: ""))
        listStack.isHidden = true
        summaryLabel.text = ""

        loadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard AccessTokenHolder.shared.current() != nil else {
                self.isLoggedIn = false
                self.applyLoggedOutState()
                return
            }
            self.isLoggedIn = true

            do {
                let response = try await BangumiQueueNetworkHandle.fetchIntro()
                guard !Task.isCancelled else { return }
                self.items = WelcomeShellDataMapper.queueCards(from: response.bangumiList)
                self.rebuildList()
            } catch {
                guard !Task.isCancelled else { return }
                do {
                    let homepage = try await self.service.loadHomepage()
                    guard !Task.isCancelled else { return }
                    self.items = WelcomeShellDataMapper.queueCards(from: homepage.bangumiQueueIntroList)
                    self.rebuildList()
                } catch {
                    guard !Task.isCancelled else { return }
                    self.items = []
                    self.listStack.isHidden = true
                    self.summaryLabel.text = ""
                    self.stateView.isHidden = false
                    self.stateView.configure(
                        title: NSLocalizedString("未看番剧加载失败", comment: ""),
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
    }

    private func rebuildList() {
        listStack.arrangedSubviews.forEach {
            listStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !items.isEmpty else {
            listStack.isHidden = true
            summaryLabel.text = ""
            stateView.isHidden = false
            stateView.configure(
                title: NSLocalizedString("暂无未看剧集", comment: ""),
                detail: NSLocalizedString("关注的番剧有新剧集时会出现在这里", comment: "")
            )
            layoutContent()
            return
        }

        stateView.isHidden = true
        listStack.isHidden = false
        summaryLabel.text = String(format: NSLocalizedString("共 %d 部作品", comment: ""), items.count)

        for (index, item) in items.enumerated() {
            let row = WelcomeShellQueueRowView()
            row.configure(with: item)
            row.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.queuePageItemPrefix)\(index)")
            row.onClick = { [weak self] in
                self?.router?.openDetail(animeId: item.animeId)
            }
            listStack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.width.equalTo(listStack)
            }
        }
        layoutContent()
    }

    private func applyLoggedOutState() {
        listStack.isHidden = true
        summaryLabel.text = ""
        stateView.isHidden = false
        stateView.configure(
            title: NSLocalizedString("登录后查看未看番剧", comment: ""),
            detail: NSLocalizedString("加载追番队列需要登录弹弹play账号", comment: ""),
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
