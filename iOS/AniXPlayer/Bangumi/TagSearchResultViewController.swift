//
//  TagSearchResultViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/8.
//

import UIKit
import SnapKit
import MJRefresh

extension SearchBangumiDetails: AnimeListItem { }

class TagSearchResultViewController: ViewController {

    private let tag: String

    private var items: [SearchBangumiDetails] = []

    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 150
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.registerClassCell(class: AnimeListTableViewCell.self)
        tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(startRefresh))
        return tableView
    }()

    private lazy var ratingNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.roundingMode = .halfEven
        return formatter
    }()

    init(tag: String) {
        self.tag = tag
        super.init(nibName: nil, bundle: nil)
        self.title = tag
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
        SearchNetworkHandle.searchByTag(self.tag) { [weak self] res, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.tableView.mj_header?.endRefreshing()
                if let error = error {
                    self.view.showError(error)
                } else {
                    self.items = res?.bangumis ?? []
                    self.tableView.reloadData()
                }
            }
        }
    }
}

extension TagSearchResultViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: AnimeListTableViewCell.self, indexPath: indexPath)
        let item = items[indexPath.row]
        cell.update(item: item, ratingNumberFormatter: ratingNumberFormatter)
        cell.didTouchLikeButton = { [weak self] (aCell, isLike) in
            guard let self = self,
                  let indexPath = self.tableView.indexPath(for: aCell) else { return }

            let animeId = self.items[indexPath.row].animeId
            aCell.favoritedButton.isUserInteractionEnabled = false

            FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { [weak self, weak aCell] error in
                guard let self = self, let aCell = aCell else { return }

                DispatchQueue.main.async {
                    aCell.favoritedButton.isUserInteractionEnabled = true
                    if let error = error {
                        self.view.showError(error)
                    }
                }
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        let vc = BangumiDetailViewController(animateId: item.animeId)
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
