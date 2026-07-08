//
//  BangumiCommentListViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/8.
//

import UIKit
import MJRefresh

class BangumiCommentListViewController: ViewController {

    private let bangumiId: String

    private var comments: [BangumiComment] = []

    private var currentPage = 0

    private var hasMore = true

    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 80
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.registerClassCell(class: BangumiCommentTableViewCell.self)

        tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(startRefresh))

        let footer = RefreshFooter(refreshingTarget: self, refreshingAction: #selector(loadMore))
        tableView.mj_footer = footer

        return tableView
    }()

    init(bangumiId: String) {
        self.bangumiId = bangumiId
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("短评论", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        self.tableView.mj_header?.beginRefreshing()
    }

    @objc private func startRefresh() {
        self.currentPage = 0
        self.hasMore = true
        self.tableView.mj_footer?.resetNoMoreData()

        BangumiNetworkHandle.comments(bangumiId: self.bangumiId, page: self.currentPage) { [weak self] res, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.tableView.mj_header?.endRefreshing()

                if let error = error {
                    self.view.showError(error)
                } else {
                    self.comments = res?.comments ?? []
                    self.hasMore = res?.hasMore ?? false
                    self.tableView.reloadData()

                    if !self.hasMore {
                        self.tableView.mj_footer?.endRefreshingWithNoMoreData()
                    }
                }
            }
        }
    }

    @objc private func loadMore() {
        guard hasMore else {
            self.tableView.mj_footer?.endRefreshingWithNoMoreData()
            return
        }

        self.currentPage += 1

        BangumiNetworkHandle.comments(bangumiId: self.bangumiId, page: self.currentPage) { [weak self] res, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let error = error {
                    self.tableView.mj_footer?.endRefreshing()
                    self.view.showError(error)
                } else {
                    if let newComments = res?.comments, !newComments.isEmpty {
                        self.comments.append(contentsOf: newComments)
                    }
                    self.hasMore = res?.hasMore ?? false
                    self.tableView.reloadData()

                    if self.hasMore {
                        self.tableView.mj_footer?.endRefreshing()
                    } else {
                        self.tableView.mj_footer?.endRefreshingWithNoMoreData()
                    }
                }
            }
        }
    }
}

extension BangumiCommentListViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: BangumiCommentTableViewCell.self, indexPath: indexPath)
        cell.update(comment: comments[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
