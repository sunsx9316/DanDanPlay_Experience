//
//  HomePageViewController.swift
//  AniXPlayer
//
//  tvOS 首页 — TableView 结构，参考 iOS 实现
//

import UIKit
import SnapKit

class HomePageViewController: ViewController {

    private enum CellType: Int, CaseIterable {
        case banner
        case function
        case continueWatching
    }

    private var dataSource: Homepage? {
        didSet {
            tableView.reloadData()
        }
    }

    private var continueWatchingItems: [BangumiQueueIntro] = []

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.register(HomePageBannerCell.self, forCellReuseIdentifier: HomePageBannerCell.reuseIdentifier)
        tv.register(HomePageFunctionCell.self, forCellReuseIdentifier: HomePageFunctionCell.reuseIdentifier)
        tv.register(HomePageContinueWatchingCell.self, forCellReuseIdentifier: HomePageContinueWatchingCell.reuseIdentifier)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 200
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("主页", comment: "")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadData()
    }

    private var notificationObserver: NSObjectProtocol?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        loadData()

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .AnixUserLoginStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadData()
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defaultFocusView = tableView
    }

    // MARK: - Data

    private func loadData() {
        HomePageNetworkHandle.homePage() { [weak self] homepage, error in
            guard let self = self else { return }
            if let homepage = homepage {
                // 继续播放仅在登录后显示
                if Preferences.shared.loginInfo != nil {
                    self.continueWatchingItems = homepage.bangumiQueueIntroList
                }
                DispatchQueue.main.async {
                    self.dataSource = homepage
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension HomePageViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource != nil ? CellType.allCases.count : 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let type = CellType(rawValue: indexPath.row) else { return UITableViewCell() }

        switch type {
        case .banner:
            let cell = tableView.dequeueReusableCell(withIdentifier: HomePageBannerCell.reuseIdentifier, for: indexPath) as! HomePageBannerCell
            cell.banners = dataSource?.banners ?? []
            return cell

        case .function:
            let cell = tableView.dequeueReusableCell(withIdentifier: HomePageFunctionCell.reuseIdentifier, for: indexPath) as! HomePageFunctionCell
            cell.onItemSelected = { [weak self] itemType in
                switch itemType {
                case .timeline:
                    let vc = TimelineViewController()
                    self?.navigationController?.pushViewController(vc, animated: true)
                case .favorite:
                    let vc = FavoriteViewController()
                    self?.navigationController?.pushViewController(vc, animated: true)
                }
            }
            return cell

        case .continueWatching:
            let cell = tableView.dequeueReusableCell(withIdentifier: HomePageContinueWatchingCell.reuseIdentifier, for: indexPath) as! HomePageContinueWatchingCell
            cell.items = continueWatchingItems
            cell.onItemSelected = { [weak self] item in
                let detailVC = BangumiDetailViewController(animateId: item.animeId)
                self?.navigationController?.pushViewController(detailVC, animated: true)
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension HomePageViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let type = CellType(rawValue: indexPath.row) else { return 0 }

        switch type {
        case .banner:
            return dataSource?.banners.isEmpty == false ? 360 : 0
        case .function:
            return 100
        case .continueWatching:
            return continueWatchingItems.isEmpty ? 0 : 275
        }
    }
}
