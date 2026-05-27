//
//  DanmakuListViewController.swift
//  AniXPlayer
//
//  tvOS 弹幕列表
//

import UIKit
import SnapKit
import DanmakuRender

class DanmakuListViewController: ViewController {

    private let danmakuModel: PlayerDanmakuModel

    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DanmakuListCell.self, forCellReuseIdentifier: DanmakuListCell.reuseIdentifier)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        return tableView
    }()

    init(danmakuModel: PlayerDanmakuModel) {
        self.danmakuModel = danmakuModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("弹幕列表", comment: "")

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.leading.equalToSuperview().offset(40)
        }
    }

    private var danmakuList: [DanmakuEntity] {
        return self.danmakuModel.danmakuList
    }
}

extension DanmakuListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.danmakuList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DanmakuListCell.reuseIdentifier, for: indexPath) as! DanmakuListCell
        cell.configure(danmaku: self.danmakuList[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
