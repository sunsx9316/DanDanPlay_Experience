//
//  BangumiDetailEpisodeViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SnapKit

extension BangumiDetailEpisodeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension BangumiDetailEpisodeViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueCell(class: TitleDetailTableViewCell.self, indexPath: indexPath)
        if let data = self.dataSource?[indexPath.row] {
            cell.titleLabel.text = data.episodeTitle
            
            var str = NSLocalizedString("分集: ", comment: "") + data.episodeNumber
            
            if !data.lastWatched.isEmpty && (self.dateFormatter.date(from: data.lastWatched) != nil) {
                str.append("\n" + NSLocalizedString("上次观看时间: ", comment: "") + data.lastWatched)
            }
            
            if !data.airDate.isEmpty && (self.dateFormatter.date(from: data.airDate) != nil)  {
                str.append("\n" + NSLocalizedString("上映时间: ", comment: "") + data.airDate)
            }
            
            cell.subtitleLabel.text = str
        }
        return cell
        
    }
}

class BangumiDetailEpisodeViewController: ViewController {

    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.registerNibCell(class: TitleDetailTableViewCell.self)
        return tableView
    }()
    
    private lazy var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter
    }()

    
    var dataSource: [BangumiEpisode]? {
        didSet {
            self.tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("分集信息", comment: "")

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

}
