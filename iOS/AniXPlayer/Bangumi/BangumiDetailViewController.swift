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
        switch cellType {
        case .episodes:
            let vc = BangumiDetailEpisodeViewController()
            vc.dataSource = self.detail?.episodes
            self.navigationController?.pushViewController(vc, animated: true)
        case .info:
            let vc = BangumiDetailMetadataViewController()
            vc.update(metaData: self.detail?.metadata, titles: self.detail?.titles, onlineDatabases: self.detail?.onlineDatabases)
            self.navigationController?.pushViewController(vc, animated: true)
        case .comments:
            let bangumiId: String = { if let id = self.detail?.bangumiId, !id.isEmpty { return id } else { return String(self.animateId) } }()
            let vc = BangumiCommentListViewController(bangumiId: bangumiId)
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellType = self.cellTypes[indexPath.row]
        switch cellType {
        case .info, .episodes, .tags:
            return UITableView.automaticDimension
        case .comments:
            return self.commentCount > 0 ? UITableView.automaticDimension : 0.01
        case .relateds:
            return self.detail?.relateds.isEmpty == false ? UITableView.automaticDimension : 0.01
        case .similars:
            return self.detail?.similars.isEmpty == false ? UITableView.automaticDimension : 0.01
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
            let cell = tableView.dequeueCell(class: BangumiDetailInfoTableViewCell.self, indexPath: indexPath)
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
        case .tags:
            let cell = tableView.dequeueCell(class: TagListTableViewCell.self, indexPath: indexPath)
            if let tags = self.detail?.tags, !tags.isEmpty {
                cell.update(tags: tags)
                cell.didTouchTagButton = { [weak self] tag in
                    guard let self = self else { return }
                    let vc = TagSearchResultViewController(tag: tag.name)
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
            return cell
        case .episodes:
            let cell = tableView.dequeueCell(class: TitleDetailMoreTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = NSLocalizedString("分集详情", comment: "")
            cell.subtitleLabel.text = NSLocalizedString("分集信息、观看信息等", comment: "")
            return cell
        case .comments:
            let cell = tableView.dequeueCell(class: TitleDetailMoreTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = NSLocalizedString("短评论", comment: "")
            if self.commentCount > 0 {
                cell.subtitleLabel.text = String(format: NSLocalizedString("%d 条评论", comment: ""), self.commentCount)
            } else {
                cell.subtitleLabel.text = NSLocalizedString("暂无评论", comment: "")
            }
            return cell
        case .relateds:
            return dequeueRelatedCell(tableView, title: NSLocalizedString("关联作品", comment: ""), intros: self.detail?.relateds, at: indexPath)
        case .similars:
            return dequeueRelatedCell(tableView, title: NSLocalizedString("相似作品", comment: ""), intros: self.detail?.similars, at: indexPath)
        }
    }

    private func dequeueRelatedCell(_ tableView: UITableView, title: String, intros: [BangumiIntro]?, at indexPath: IndexPath) -> BangumiDetailRelatedTableViewCell {
        let cell = tableView.dequeueCell(class: BangumiDetailRelatedTableViewCell.self, indexPath: indexPath)
        cell.titleLabel.text = title
        cell.bangumiIntros = intros
        cell.didSelectedAnimateCallBack = { [weak self] animateId in
            guard let self = self else { return }
            self.jumpToBangumiDetail(aniamteId: animateId)
        }
        cell.refreshDataCallBack = { [weak self] in
            self?.startRefresh()
        }
        return cell
    }

    private func jumpToBangumiDetail(aniamteId: Int) {
        let vc = BangumiDetailViewController(animateId: aniamteId)
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

class BangumiDetailViewController: ViewController {

    enum CellType: CaseIterable {
        case info
        case tags
        case episodes
        case comments
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
        tableView.registerClassCell(class: BangumiDetailInfoTableViewCell.self)
        tableView.registerClassCell(class: BangumiDetailRelatedTableViewCell.self)
        tableView.registerClassCell(class: TitleDetailMoreTableViewCell.self)
        tableView.registerClassCell(class: TagListTableViewCell.self)

        tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(startRefresh))
        return tableView
    }()

    lazy var ratingNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.roundingMode = .halfEven
        return formatter
    }()

    private var animateId = 0

    private var cellTypes: [CellType] = []

    private var commentCount = 0

    private var detail: BangumiDetail? {
        didSet {
            self.title = self.detail?.animeTitle
            self.updateCellTypes()
            self.fetchCommentCount()
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

    // MARK: Private

    private func updateCellTypes() {
        var types: [CellType] = [.info]

        if let tags = self.detail?.tags, !tags.isEmpty {
            types.append(.tags)
        }

        types.append(.episodes)
        types.append(.comments)
        types.append(.relateds)
        types.append(.similars)

        self.cellTypes = types
    }

    private func fetchCommentCount() {
        let bangumiId: String = { if let id = self.detail?.bangumiId, !id.isEmpty { return id } else { return String(self.animateId) } }()

        BangumiNetworkHandle.comments(bangumiId: bangumiId, page: 0) { [weak self] res, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.commentCount = res?.count ?? 0
                self.tableView.reloadData()
            }
        }
    }

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
