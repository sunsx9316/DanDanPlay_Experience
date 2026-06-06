//
//  BangumiDetailViewController.swift
//  AniXPlayer
//
//  tvOS 番剧详情 — TableView 结构，信息区域横向布局
//

import UIKit
import SnapKit

class BangumiDetailViewController: ViewController {

    private enum Section: Int, CaseIterable {
        case info
        case episodes
    }

    private let animeId: Int

    private var detail: BangumiDetail? {
        didSet {
            self.title = detail?.animeTitle
            tableView.reloadData()
        }
    }

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: BangumiDetailInfoCell.self)
        tv.registerClassCell(class: EpisodeCell.self)
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
}

// MARK: - UITableViewDataSource

extension BangumiDetailViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return detail != nil ? Section.allCases.count : 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .info: return 1
        case .episodes: return detail?.episodes.count ?? 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .info:
            let cell = tableView.dequeueCell(class: BangumiDetailInfoCell.self, indexPath: indexPath)
            if let detail = detail {
                cell.configure(with: detail)
            }
            return cell

        case .episodes:
            let cell = tableView.dequeueCell(class: EpisodeCell.self, indexPath: indexPath)
            if let episode = detail?.episodes[indexPath.row] {
                cell.configure(with: episode)
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension BangumiDetailViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .info:
            return UITableView.automaticDimension
        case .episodes:
            return 80
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .info:
            break
        case .episodes:
            break
        }
    }
}
