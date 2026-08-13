//
//  BangumiCommentListViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/10.
//

import Cocoa
import SnapKit

class BangumiCommentListViewController: ViewController, NSTableViewDataSource, NSTableViewDelegate {

    private let bangumiId: String

    private var comments: [BangumiComment] = []

    private var currentPage = 0

    private var hasMore = true

    private var isLoading = false

    private lazy var tableView: TableView = {
        let tv = TableView()
        tv.dataSource = self
        tv.delegate = self
        tv.backgroundColor = .backgroundColor
        tv.headerView = nil
        tv.rowSizeStyle = .custom
        tv.registerClassCell(class: BangumiCommentTableViewCell.self)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("comment"))
        column.width = 500
        tv.addTableColumn(column)

        return tv
    }()

    private lazy var scrollView: ScrollView<TableView> = {
        let sv = ScrollView<TableView>()
        sv.containerView = tableView
        sv.hasVerticalScroller = true
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

    private lazy var loadingLabel: Label = {
        let label = Label(labelWithString: NSLocalizedString("加载中...", comment: ""))
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.alignment = .center
        label.isHidden = true
        return label
    }()

    init(bangumiId: String) {
        self.bangumiId = bangumiId
        super.init()
        self.title = NSLocalizedString("短评论", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(scrollView)
        view.addSubview(loadingLabel)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadingLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
        }

        startRefresh()
    }

    // MARK: - Private

    private func startRefresh() {
        currentPage = 0
        hasMore = true
        isLoading = true
        loadComments()
    }

    private func loadMore() {
        guard hasMore, !isLoading else { return }
        currentPage += 1
        isLoading = true
        loadComments()
    }

    private func loadComments() {
        loadingLabel.isHidden = false

        BangumiNetworkHandle.comments(bangumiId: bangumiId, page: currentPage) { [weak self] res, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false
                self.loadingLabel.isHidden = true

                if let error = error {
                    self.view.show(error: error)
                } else if self.currentPage == 0 {
                    self.comments = res?.comments ?? []
                    self.hasMore = res?.hasMore ?? false
                    self.tableView.reloadData()
                } else if let newComments = res?.comments, !newComments.isEmpty {
                    self.comments.append(contentsOf: newComments)
                    self.hasMore = res?.hasMore ?? false
                    self.tableView.reloadData()
                } else {
                    self.hasMore = false
                }
            }
        }
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        guard let clipView = notification.object as? NSClipView else { return }
        let scrollPosition = clipView.bounds.origin.y + clipView.bounds.height
        let contentHeight = clipView.documentView?.bounds.height ?? 0

        if scrollPosition >= contentHeight - 60 {
            loadMore()
        }
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

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 80
    }
}
