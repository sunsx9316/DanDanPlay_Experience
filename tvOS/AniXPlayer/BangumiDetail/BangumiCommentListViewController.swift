//
//  BangumiCommentListViewController.swift
//  AniXPlayer
//
//  tvOS 短评论列表页 — 分页加载，Focus Engine 适配
//

import UIKit

class BangumiCommentListViewController: ViewController {

    private let bangumiId: String

    private var comments: [BangumiComment] = []

    private var currentPage = 0

    private var hasMore = true

    private var isLoading = false

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.estimatedRowHeight = 120
        tv.rowHeight = UITableView.automaticDimension
        tv.registerClassCell(class: BangumiCommentTableViewCell.self)
        return tv
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

        loadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = tableView
    }

    // MARK: Data

    private func loadData() {
        guard !isLoading else { return }
        isLoading = true

        BangumiNetworkHandle.comments(bangumiId: self.bangumiId, page: self.currentPage) { [weak self] res, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.view.showError(error)
                } else {
                    if let newComments = res?.comments, !newComments.isEmpty {
                        let startIndex = self.comments.count
                        self.comments.append(contentsOf: newComments)
                        self.hasMore = res?.hasMore ?? false
                        if self.currentPage == 0 {
                            self.tableView.reloadData()
                        } else {
                            let indexPaths = (startIndex..<self.comments.count).map { IndexPath(row: $0, section: 0) }
                            self.tableView.insertRows(at: indexPaths, with: .automatic)
                        }
                    } else {
                        self.hasMore = false
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }

    private func loadMore() {
        guard hasMore, !isLoading else { return }
        currentPage += 1
        loadData()
    }
}

// MARK: - UITableViewDataSource

extension BangumiCommentListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: BangumiCommentTableViewCell.self, indexPath: indexPath)
        cell.update(comment: comments[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension BangumiCommentListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // 滚动到倒数第3条时自动加载更多
        if hasMore, !isLoading, indexPath.row >= comments.count - 3 {
            loadMore()
        }
    }
}
