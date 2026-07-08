//
//  FavoriteViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SnapKit
import MJRefresh

class FavoriteViewController: ViewController {

    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 150
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.registerClassCell(class: FavoriteTableViewCell.self)
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

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private var dataSources: [UserFavoriteItem] = []

    var didSelectedAnimateCallBack: ((Int) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("我的关注", comment: "")

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        self.tableView.mj_header?.beginRefreshing()
    }

    @objc private func startRefresh() {
        FavoriteNetworkHandle.getFavoriteList { [weak self] res, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.tableView.mj_header?.endRefreshing()
                if let error = error {
                    self.view.showError(error)
                } else {
                    self.dataSources = res?.favorites ?? []
                    self.tableView.reloadData()
                }
            }
        }
    }
}

extension FavoriteViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSources.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: FavoriteTableViewCell.self, indexPath: indexPath)
        let item = dataSources[indexPath.row]
        cell.update(item: item, ratingNumberFormatter: ratingNumberFormatter)
        cell.didTouchLikeButton = { [weak self] (aCell, isLike) in
            guard let self = self,
                  let indexPath = self.tableView.indexPath(for: aCell) else { return }

            let animeId = self.dataSources[indexPath.row].animeId
            aCell.favoritedButton.isUserInteractionEnabled = false

            FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { [weak self, weak aCell] error in
                guard let self = self, let aCell = aCell else { return }

                DispatchQueue.main.async {
                    aCell.favoritedButton.isUserInteractionEnabled = true
                    if let error = error {
                        self.view.showError(error)
                    } else {
                        self.startRefresh()
                    }
                }
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let item = dataSources[indexPath.row]
        if item.animeId != 0 {
            let vc = BangumiDetailViewController(animateId: item.animeId)
            self.navigationController?.pushViewController(vc, animated: true)
            self.didSelectedAnimateCallBack?(item.animeId)
        }
    }
}
