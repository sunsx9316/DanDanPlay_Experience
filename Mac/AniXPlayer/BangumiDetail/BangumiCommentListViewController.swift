//
//  BangumiCommentListViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/10.
//

import Cocoa
import SnapKit

final class BangumiCommentListViewController: ViewController, NSTableViewDataSource, NSTableViewDelegate {

    private let bangumiId: String
    private let maximumPage = 9

    private var comments: [BangumiComment] = []
    private var nextPage = 0
    private var hasMore = true
    private var isLoading = false
    private var hasLoadedOnce = false
    private var needsLogin = false
    private var lastError: String?
    private var requestID = 0

    private lazy var tableView: TableView = {
        let tv = TableView()
        tv.dataSource = self
        tv.delegate = self
        tv.backgroundColor = .backgroundColor
        tv.headerView = nil
        tv.rowSizeStyle = .custom
        tv.rowHeight = 80
        tv.usesAutomaticRowHeights = true
        tv.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tv.registerClassCell(class: BangumiCommentTableViewCell.self)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("comment"))
        column.width = 500
        column.resizingMask = .autoresizingMask
        tv.addTableColumn(column)
        return tv
    }()

    private lazy var scrollView: ScrollView<TableView> = {
        let sv = ScrollView<TableView>()
        sv.containerView = tableView
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers = true
        sv.horizontalScrollElasticity = .none
        sv.borderType = .noBorder
        sv.drawsBackground = false

        sv.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: sv.contentView
        )
        return sv
    }()

    private let spinner: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isDisplayedWhenStopped = false
        return indicator
    }()
    private let stateView = WelcomeShellStateView()
    private let statusStack = NSStackView()
    private let footerLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        return label
    }()
    private let footerRetryButton = WelcomeShellClosureButton(title: NSLocalizedString("重试", comment: ""))
    private let footerStack = NSStackView()

    init(bangumiId: String) {
        self.bangumiId = bangumiId
        super.init()
        title = NSLocalizedString("短评论", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.commentList)
        buildLayout()
        loadFirstPage()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        fillViewportIfNeeded()
    }

    // MARK: - Layout

    private func buildLayout() {
        spinner.isHidden = true
        stateView.isHidden = true
        stateView.setAccessibilityIdentifier("\(AccessibilityID.BangumiDetail.commentList).state")
        footerStack.setAccessibilityIdentifier("\(AccessibilityID.BangumiDetail.commentList).footer")
        statusStack.orientation = .vertical
        statusStack.alignment = .centerX
        statusStack.spacing = 8
        statusStack.detachesHiddenViews = true
        statusStack.addArrangedSubview(spinner)
        statusStack.addArrangedSubview(stateView)

        footerLabel.isHidden = true
        footerRetryButton.isBordered = false
        footerRetryButton.contentTintColor = .mainColor
        footerRetryButton.font = .systemFont(ofSize: 11.5, weight: .medium)
        footerRetryButton.isHidden = true
        footerRetryButton.onClick = { [weak self] in
            self?.loadMore()
        }
        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.spacing = 8
        footerStack.addArrangedSubview(footerLabel)
        footerStack.addArrangedSubview(footerRetryButton)
        footerStack.isHidden = true

        view.addSubview(scrollView)
        view.addSubview(statusStack)
        view.addSubview(footerStack)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        statusStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }
        footerStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
        }
    }

    // MARK: - Data

    private func loadFirstPage() {
        requestID += 1
        comments = []
        nextPage = 0
        hasMore = true
        isLoading = false
        hasLoadedOnce = false
        needsLogin = false
        lastError = nil
        tableView.reloadData()
        loadPage(0, isFirstPage: true)
    }

    private func loadMore() {
        guard hasLoadedOnce, hasMore, !isLoading, nextPage <= maximumPage else { return }
        loadPage(nextPage, isFirstPage: false)
    }

    private func loadPage(_ page: Int, isFirstPage: Bool) {
        guard !isLoading else { return }
        isLoading = true
        needsLogin = false
        lastError = nil
        refreshStatus()
        let currentRequestID = requestID

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                self.isLoading = false
                self.needsLogin = true
                self.lastError = NSLocalizedString("需要登录", comment: "")
                self.refreshStatus()
                return
            }

            BangumiNetworkHandle.comments(bangumiId: self.bangumiId, page: page) { [weak self] response, error in
                guard let self = self, self.requestID == currentRequestID else { return }
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.lastError = error.localizedDescription
                        self.refreshStatus()
                        return
                    }

                    let received = response?.comments ?? []
                    if isFirstPage {
                        self.comments = received
                    } else if !received.isEmpty {
                        self.comments.append(contentsOf: received)
                    }
                    self.nextPage = page + 1
                    self.hasMore = page < self.maximumPage && (response?.hasMore ?? false)
                    self.hasLoadedOnce = true
                    self.needsLogin = false
                    self.lastError = nil
                    self.tableView.reloadData()
                    self.refreshStatus()
                    self.fillViewportIfNeeded()
                }
            }
        }
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        guard let clipView = notification.object as? NSClipView else { return }
        let scrollPosition = clipView.bounds.origin.y + clipView.bounds.height
        let contentHeight = tableView.numberOfRows > 0
            ? tableView.rect(ofRow: tableView.numberOfRows - 1).maxY
            : 0

        if scrollPosition >= contentHeight - 80 {
            loadMore()
        }
    }

    private func fillViewportIfNeeded() {
        guard !comments.isEmpty, hasMore, !isLoading else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tableView.layoutSubtreeIfNeeded()
            let visibleHeight = self.scrollView.contentView.bounds.height
            let contentHeight = self.tableView.numberOfRows > 0
                ? self.tableView.rect(ofRow: self.tableView.numberOfRows - 1).maxY
                : 0
            if contentHeight < visibleHeight + 80 {
                self.loadMore()
            }
        }
    }

    private func refreshStatus() {
        let isFirstLoad = !hasLoadedOnce
        let hasComments = !comments.isEmpty

        if hasComments {
            stopSpinner()
            statusStack.isHidden = true
        } else if isLoading && isFirstLoad {
            statusStack.isHidden = false
            spinner.isHidden = false
            spinner.startAnimation(nil)
            stateView.isHidden = false
            stateView.configure(title: NSLocalizedString("正在加载短评…", comment: ""))
        } else if isFirstLoad, needsLogin {
            stopSpinner()
            statusStack.isHidden = false
            stateView.isHidden = false
            stateView.configure(
                title: NSLocalizedString("登录后查看短评", comment: ""),
                actionTitle: NSLocalizedString("登录", comment: ""),
                onAction: { [weak self] in
                    self?.loadFirstPage()
                }
            )
            stateView.setActionAccessibilityIdentifier(AccessibilityID.BangumiDetail.stateAction)
        } else if isFirstLoad, let error = lastError {
            stopSpinner()
            statusStack.isHidden = false
            stateView.isHidden = false
            stateView.configure(
                title: NSLocalizedString("短评加载失败", comment: ""),
                detail: error,
                actionTitle: NSLocalizedString("重试", comment: ""),
                onAction: { [weak self] in
                    self?.loadFirstPage()
                }
            )
            stateView.setActionAccessibilityIdentifier(AccessibilityID.BangumiDetail.stateAction)
        } else if isFirstLoad {
            stopSpinner()
            statusStack.isHidden = false
            stateView.isHidden = false
            stateView.configure(title: NSLocalizedString("还没有短评", comment: ""))
        } else {
            stopSpinner()
            statusStack.isHidden = false
            stateView.isHidden = false
            stateView.configure(title: NSLocalizedString("还没有短评", comment: ""))
        }

        if isLoading && !isFirstLoad {
            footerStack.isHidden = false
            footerLabel.isHidden = false
            footerLabel.text = NSLocalizedString("正在加载更多短评…", comment: "")
            footerRetryButton.isHidden = true
        } else if !isFirstLoad, let error = lastError, hasComments {
            footerStack.isHidden = false
            footerLabel.isHidden = false
            footerLabel.text = error
            footerRetryButton.isHidden = false
        } else {
            footerStack.isHidden = true
            footerLabel.isHidden = true
            footerRetryButton.isHidden = true
        }
    }

    private func stopSpinner() {
        spinner.stopAnimation(nil)
        spinner.isHidden = true
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return comments.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.dequeueReusableCell(class: BangumiCommentTableViewCell.self)
        cell.update(comment: comments[row])
        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
}
