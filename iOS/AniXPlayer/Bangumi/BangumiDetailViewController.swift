//
//  BangumiDetailViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SnapKit
import MJRefresh

extension BangumiDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let cellType = self.cellTypes[indexPath.row]
        if cellType == .episodes {
            let vc = BangumiDetailEpisodeViewController()
            vc.dataSource = self.detail?.episodes
            self.navigationController?.pushViewController(vc, animated: true)
        } else if cellType == .info {
            let vc = BangumiDetailMetadataViewController()
            vc.update(metaData: self.detail?.metadata, titles: self.detail?.titles, onlineDatabases: self.detail?.onlineDatabases)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellType = self.cellTypes[indexPath.row]
        switch cellType {
        case .info:
            return UITableView.automaticDimension
        case .episodes:
            return UITableView.automaticDimension
        case .relateds:
            if self.detail?.relateds.isEmpty == false {
                return 180
            }
            return 0.01
        case .similars:
            if self.detail?.similars.isEmpty == false {
                return 180
            }
            return 0.01
        }
    }
}

extension BangumiDetailViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.detail != nil ? self.cellTypes.count : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch self.cellTypes[indexPath.row] {
        
        case .info:
            let cell = tableView.dequeueCell(class: BangumiDetailInfoViewCell.self, indexPath: indexPath)
            cell.update(item: self.detail, ratingNumberFormatter: self.ratingNumberFormatter)
            cell.didTouchLikeButton = { [weak self] (aCell, isLike) in
                guard let self = self, let animeId = aCell.item?.animeId else { return }
                
                aCell.favoritedButton.isUserInteractionEnabled = false
                
                FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { [weak self, weak aCell] error in
                    guard let self = self, let aCell = aCell else { return }
                    
                    DispatchQueue.main.async {
                        aCell.favoritedButton.isUserInteractionEnabled = true
                        if let error = error {
                            self.view.showError(error)
                        } else {
                            aCell.item?.isFavorited = isLike
                        }
                    }
                }
            }
            return cell
        case .episodes:
            let cell = tableView.dequeueCell(class: TitleDetailMoreTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = NSLocalizedString("分集详情", comment: "")
            cell.subtitleLabel.text = NSLocalizedString("分集信息、观看信息等", comment: "")
            return cell
        case .relateds:
            let cell = tableView.dequeueCell(class: BangumiDetailRelatedTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = NSLocalizedString("关联作品", comment: "")
            cell.bangumiIntros = self.detail?.relateds
            cell.didSelectedAnimateCallBack = { [weak self] animateId in
                guard let self = self else { return }
                
                self.jumpToBangumiDetail(aniamteId: animateId)
            }
            return cell
        case .similars:
            let cell = tableView.dequeueCell(class: BangumiDetailRelatedTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = NSLocalizedString("相似作品", comment: "")
            cell.bangumiIntros = self.detail?.similars
            cell.didSelectedAnimateCallBack = { [weak self] animateId in
                guard let self = self else { return }
                
                self.jumpToBangumiDetail(aniamteId: animateId)
            }
            return cell
        }
        
        
    }
    
    private func jumpToBangumiDetail(aniamteId: Int) {
        let vc = BangumiDetailViewController(animateId: aniamteId)
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

class BangumiDetailViewController: ViewController {
    
    enum CellType: CaseIterable {
        case info
        case episodes
        case relateds
        case similars
    }
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.registerNibCell(class: BangumiDetailInfoViewCell.self)
        tableView.registerNibCell(class: TitleDetailTableViewCell.self)
        tableView.registerNibCell(class: TitleTableViewCell.self)
        tableView.registerClassCell(class: BangumiDetailRelatedTableViewCell.self)
        tableView.registerNibCell(class: TitleDetailMoreTableViewCell.self)
        
        tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(startRefresh))
        return tableView
    }()
    
    private lazy var ratingNumberFormatter: NumberFormatter = {
        var ratingNumberFormatter = NumberFormatter()
        ratingNumberFormatter.numberStyle = .decimal
        ratingNumberFormatter.minimumFractionDigits = 1
        ratingNumberFormatter.roundingMode = .halfEven
        return ratingNumberFormatter
    }()
    
    private var animateId = 0
    
    private var cellTypes = CellType.allCases
    
    private var detail: BangumiDetail? {
        didSet {
            self.title = self.detail?.animeTitle
            self.tableView.reloadData()
        }
    }
    
    init(animateId: Int) {
        super.init(nibName: nil, bundle: nil)
        self.animateId = animateId
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
    
    // MARK: Private Method
    @objc private func startRefresh() {
        BangumiNetworkHandle.detail(animateId: self.animateId) { [weak self] res, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.tableView.mj_header?.endRefreshing()
                if let error = error {
                    self.view.showError(error)
                } else {
                    self.detail = res?.bangumi
                }
            }
        }
    }
}
