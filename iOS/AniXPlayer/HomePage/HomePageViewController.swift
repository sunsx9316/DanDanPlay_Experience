//
//  HomePageViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit
import SnapKit

extension HomePageViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.dataSource == nil {
            return 0
        }
        return self.cellDataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.cellDataSource[indexPath.row]
        
        switch type {
        case .banner:
            let cell = tableView.dequeueCell(class: HomePageBannerTableViewCell.self, indexPath: indexPath)
            cell.banners = self.dataSource?.banners
            return cell
        case .function:
            let cell = tableView.dequeueCell(class: HomePageFunctionTableViewCell.self, indexPath: indexPath)
            cell.didSelectedItemCallBack = { [weak self] itemType in
                guard let self = self else { return }
                
                switch itemType {
                case .timeLine:
                    let vc = TimelineViewController()
                    vc.dataSource = self.dataSource?.shinBangumiList
                    vc.hidesBottomBarWhenPushed = true
                    self.navigationController?.pushViewController(vc, animated: true)
                case .favorite:
                    let vc = FavoriteViewController()
                    vc.hidesBottomBarWhenPushed = true
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
            return cell
        case .bangumiQueue:
            let cell = tableView.dequeueCell(class: HomePageBangumiQueueTableViewCell.self, indexPath: indexPath)
            return cell
        }
    }
}


extension HomePageViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let type = self.cellDataSource[indexPath.row]
        
        switch type {
        case .banner:
            return 200
        case .function:
            return 130
        case .bangumiQueue:
            return 150
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
}

class HomePageViewController: ViewController {
    
    private enum CellType: CaseIterable {
        /// 公告
        case banner
        /// 功能区
        case function
        /// 未看剧集
        case bangumiQueue
    }
    
    private lazy var cellDataSource = CellType.allCases
    
    private var dataSource: Homepage? {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.registerClassCell(class: HomePageBannerTableViewCell.self)
        tableView.registerClassCell(class: HomePageFunctionTableViewCell.self)
        tableView.registerNibCell(class: HomePageBangumiQueueTableViewCell.self)
        tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(startRefresh))
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("主页", comment: "")
        self.navigationItem.leftBarButtonItem = nil
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.tableView.mj_header?.beginRefreshing()
    }
    
    // MARK: Private Method
    @objc private func startRefresh() {
        HomePageNetworkHandle.homePage { [weak self] homePage, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.view.showError(error)
                } else {
                    self.dataSource = homePage
                }
                
                self.tableView.mj_header?.endRefreshing()
            }
        }
    }

    

}
