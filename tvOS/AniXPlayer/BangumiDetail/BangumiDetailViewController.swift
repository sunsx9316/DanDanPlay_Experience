//
//  BangumiDetailViewController.swift
//  AniXPlayer
//
//  tvOS 番剧详情 — TableView 多 Section 结构（info / tags / episodes / comments / relateds / similars）
//

import UIKit
import SnapKit

class BangumiDetailViewController: ViewController {

    private enum Section: Int, CaseIterable {
        case info
        case tags
        case episodes
        case comments
        case relateds
        case similars
    }

    private let animeId: Int

    private var detail: BangumiDetail? {
        didSet {
            self.title = detail?.animeTitle
            recomputeSections()
            fetchCommentCount()
            tableView.reloadData()
        }
    }

    private var commentCount = 0

    private var visibleSections: [Section] = [.info]

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: BangumiDetailInfoTableViewCell.self)
        tv.registerClassCell(class: TagListTableViewCell.self)
        tv.registerClassCell(class: TitleMoreTableViewCell.self)
        tv.registerClassCell(class: BangumiDetailRelatedTableViewCell.self)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
        return tv
    }()

    init(animateId: Int) {
        self.animeId = animateId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("番剧详情", comment: "")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defaultFocusView = tableView
    }

    // MARK: Data

    private func loadData() {
        BangumiNetworkHandle.detail(animateId: animeId) { [weak self] response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let detail = response?.bangumi {
                    self.detail = detail
                }
            }
        }
    }

    private func fetchCommentCount() {
        let bangumiId: String = { if let id = self.detail?.bangumiId, !id.isEmpty { return id } else { return String(self.animeId) } }()

        BangumiNetworkHandle.comments(bangumiId: bangumiId, page: 0) { [weak self] res, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.commentCount = res?.count ?? 0
                self.tableView.reloadData()
            }
        }
    }

    private func recomputeSections() {
        guard let detail = detail else {
            visibleSections = [.info]
            return
        }
        var sections: [Section] = [.info]

        if !detail.tags.isEmpty { sections.append(.tags) }

        sections.append(.episodes)
        sections.append(.comments)

        if !detail.relateds.isEmpty { sections.append(.relateds) }
        if !detail.similars.isEmpty { sections.append(.similars) }

        visibleSections = sections
    }

    private func pushDetail(animateId: Int) {
        let vc = BangumiDetailViewController(animateId: animateId)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension BangumiDetailViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return visibleSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sec = visibleSections[safe: indexPath.section] else { return UITableViewCell() }
        switch sec {
        case .info:
            let cell = tableView.dequeueCell(class: BangumiDetailInfoTableViewCell.self, indexPath: indexPath)
            if let detail = detail {
                cell.configure(with: detail)
            }
            return cell

        case .tags:
            let cell = tableView.dequeueCell(class: TagListTableViewCell.self, indexPath: indexPath)
            if let tags = detail?.tags, !tags.isEmpty {
                cell.update(tags: tags)
                cell.didTouchTagButton = { [weak self] tag in
                    guard let self = self else { return }
                    let vc = TagSearchResultViewController(tag: tag.name)
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
            return cell

        case .episodes:
            let cell = tableView.dequeueCell(class: TitleMoreTableViewCell.self, indexPath: indexPath)
            cell.label.text = NSLocalizedString("分集详情", comment: "")
            return cell

        case .comments:
            let cell = tableView.dequeueCell(class: TitleMoreTableViewCell.self, indexPath: indexPath)
            if commentCount > 0 {
                cell.label.text = String(format: NSLocalizedString("短评论 (%d 条)", comment: ""), commentCount)
            } else {
                cell.label.text = NSLocalizedString("短评论", comment: "")
            }
            return cell

        case .relateds:
            let cell = tableView.dequeueCell(class: BangumiDetailRelatedTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = NSLocalizedString("关联作品", comment: "")
            cell.items = detail?.relateds ?? []
            cell.onItemSelected = { [weak self] animeId in
                self?.pushDetail(animateId: animeId)
            }
            return cell

        case .similars:
            let cell = tableView.dequeueCell(class: BangumiDetailRelatedTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = NSLocalizedString("相似作品", comment: "")
            cell.items = detail?.similars ?? []
            cell.onItemSelected = { [weak self] animeId in
                self?.pushDetail(animateId: animeId)
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension BangumiDetailViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let sec = visibleSections[safe: indexPath.section] else { return 0 }
        switch sec {
        case .info, .episodes, .comments, .tags:
            return UITableView.automaticDimension
        case .relateds:
            let items = detail?.relateds ?? []
            return items.isEmpty ? 0.01 : BangumiDetailRelatedTableViewCell.estimatedHeight(for: items, width: tableView.bounds.width)
        case .similars:
            let items = detail?.similars ?? []
            return items.isEmpty ? 0.01 : BangumiDetailRelatedTableViewCell.estimatedHeight(for: items, width: tableView.bounds.width)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sec = visibleSections[safe: indexPath.section] else { return }

        switch sec {
        case .episodes:
            let vc = BangumiDetailEpisodeViewController()
            vc.dataSource = detail?.episodes ?? []
            navigationController?.pushViewController(vc, animated: true)
        case .comments:
            let bangumiId: String = { if let id = self.detail?.bangumiId, !id.isEmpty { return id } else { return String(self.animeId) } }()
            let vc = BangumiCommentListViewController(bangumiId: bangumiId)
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let sec = visibleSections[safe: indexPath.section], sec == .info,
              let detail = detail else { return nil }

        let isFav = detail.isFavorited
        let title = isFav ? NSLocalizedString("取消关注", comment: "") : NSLocalizedString("关注", comment: "")

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let action = UIAction(title: title, image: nil) { [weak self] _ in
                guard let self = self else { return }
                FavoriteNetworkHandle.changeFavorite(animateId: self.animeId, isLike: !isFav) { [weak self] error in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if let error = error {
                            self.view.showError(error)
                        } else {
                            self.detail?.isFavorited = !isFav
                            self.tableView.reloadData()
                        }
                    }
                }
            }
            return UIMenu(title: "", children: [action])
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
