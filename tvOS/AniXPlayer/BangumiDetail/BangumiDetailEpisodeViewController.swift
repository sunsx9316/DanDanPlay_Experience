//
//  BangumiDetailEpisodeViewController.swift
//  AniXPlayer
//
//  tvOS 分集详情 — TableView
//

import UIKit
import SnapKit

class BangumiDetailEpisodeViewController: ViewController {

    var dataSource: [BangumiEpisode] = []

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: EpisodeCell.self)
        tv.rowHeight = 80
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("分集详情", comment: "")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defaultFocusView = tableView
    }
}

extension BangumiDetailEpisodeViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: EpisodeCell.self, indexPath: indexPath)
        if let episode = dataSource[safe: indexPath.row] {
            cell.configure(with: episode)
        }
        return cell
    }
}

extension BangumiDetailEpisodeViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
