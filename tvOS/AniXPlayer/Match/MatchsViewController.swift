//
//  MatchsViewController.swift
//  AniXPlayer
//
//  tvOS 弹幕匹配页面
//

import UIKit
import SnapKit

class MatchsViewController: ViewController {

    var file: File?

    private var matches: [Match] = []

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.register(MatchCell.self, forCellReuseIdentifier: MatchCell.reuseIdentifier)
        tv.rowHeight = 80
        return tv
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.color = .white
        return indicator
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("弹幕匹配", comment: "")

        self.view.addSubview(tableView)
        self.view.addSubview(loadingIndicator)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        startMatching()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = tableView
    }

    private func startMatching() {
        guard let file = file else { return }

        loadingIndicator.startAnimating()
        MatchNetworkHandle.match(with: file) { [weak self] collection, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()
                if let collection = collection {
                    self.matches = collection.collection
                    self.tableView.reloadData()
                }
            }
        }
    }

    private func selectMatch(_ match: Match) {
        // TODO: Phase 9 — 加载弹幕并开始播放
        let playerVC = PlayerViewController()
        self.present(playerVC, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension MatchsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matches.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MatchCell.reuseIdentifier, for: indexPath) as! MatchCell
        cell.configure(with: matches[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MatchsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectMatch(matches[indexPath.row])
    }
}
