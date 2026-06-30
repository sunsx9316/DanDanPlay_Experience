//
//  BangumiDetailViewController.swift
//  AniXPlayer
//
//  tvOS 番剧详情 — TableView 多 Section 结构（info / episodes / relateds / similars）
//

import UIKit
import SnapKit

class BangumiDetailViewController: ViewController {

    private enum Section: Int, CaseIterable {
        case info
        case episodes
        case relateds
        case similars
    }

    private let animeId: Int

    private var detail: BangumiDetail? {
        didSet {
            self.title = detail?.animeTitle
            recomputeSections()
            tableView.reloadData()
        }
    }

    private var visibleSections: [Section] = [.info]

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: BangumiDetailInfoCell.self)
        tv.registerClassCell(class: EpisodeEntryCell.self)
        tv.registerClassCell(class: BangumiDetailRelatedCell.self)
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

    private func loadData() {
        BangumiNetworkHandle.detail(animateId: animeId) { [weak self] response, error in
            guard let self = self else { return }
            if let detail = response?.bangumi {
                DispatchQueue.main.async {
                    self.detail = detail
                }
            }
        }
    }

    private func recomputeSections() {
        guard let detail = detail else {
            visibleSections = [.info]
            return
        }
        var sections: [Section] = [.info, .episodes]
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
        guard let sec = visibleSections[safe: section] else { return 0 }
        switch sec {
        case .info: return 1
        case .episodes: return 1
        case .relateds: return 1
        case .similars: return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sec = visibleSections[safe: indexPath.section] else { return UITableViewCell() }
        switch sec {
        case .info:
            let cell = tableView.dequeueCell(class: BangumiDetailInfoCell.self, indexPath: indexPath)
            if let detail = detail {
                cell.configure(with: detail)
            }
            return cell

        case .episodes:
            let cell = tableView.dequeueCell(class: EpisodeEntryCell.self, indexPath: indexPath)
            cell.configure(episodeCount: detail?.episodes.count ?? 0)
            return cell

        case .relateds:
            let cell = tableView.dequeueCell(class: BangumiDetailRelatedCell.self, indexPath: indexPath)
            cell.titleLabel.text = NSLocalizedString("关联作品", comment: "")
            cell.items = detail?.relateds ?? []
            cell.onItemSelected = { [weak self] animeId in
                self?.pushDetail(animateId: animeId)
            }
            return cell

        case .similars:
            let cell = tableView.dequeueCell(class: BangumiDetailRelatedCell.self, indexPath: indexPath)
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
        case .info:
            return UITableView.automaticDimension
        case .episodes:
            return UITableView.automaticDimension
        case .relateds:
            let items = detail?.relateds ?? []
            return BangumiDetailRelatedCell.estimatedHeight(for: items, width: tableView.bounds.width)
        case .similars:
            let items = detail?.similars ?? []
            return BangumiDetailRelatedCell.estimatedHeight(for: items, width: tableView.bounds.width)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sec = visibleSections[safe: indexPath.section], sec == .episodes else { return }
        let vc = BangumiDetailEpisodeViewController()
        vc.dataSource = detail?.episodes ?? []
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - EpisodeEntryCell

private class EpisodeEntryCell: TableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        textLabel?.font = .ddp_normal()
        textLabel?.textColor = .white
        textLabel?.text = NSLocalizedString("分集详情", comment: "")
        detailTextLabel?.font = .ddp_small()
        detailTextLabel?.textColor = .secondaryLabel
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(episodeCount: Int) {
        detailTextLabel?.text = String(format: NSLocalizedString("%d 集", comment: ""), episodeCount)
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
