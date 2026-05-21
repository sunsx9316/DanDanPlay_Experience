//
//  MatchsViewController.swift
//  AniXPlayer
//
//  tvOS 弹幕匹配页面 — 展示匹配列表，选择后通过 PlayerModel 加载弹幕并播放
//

import UIKit
import SnapKit
import RxSwift

class MatchsViewController: ViewController {

    private let collection: MatchCollection
    private let media: File
    private let playerModel: PlayerModel

    private var matches: [Match] = []
    private let bag = DisposeBag()

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.register(MatchCell.self, forCellReuseIdentifier: MatchCell.reuseIdentifier)
        tv.rowHeight = 80
        return tv
    }()

    init(collection: MatchCollection, media: File, playerModel: PlayerModel) {
        self.collection = collection
        self.media = media
        self.playerModel = playerModel
        self.matches = collection.collection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("选择弹幕匹配", comment: "")

        self.view.addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = tableView
    }

    private func selectMatch(_ match: Match) {
        self.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            _ = self.playerModel.didMatchMedia(self.media, matchInfo: match).subscribe()
        }
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
