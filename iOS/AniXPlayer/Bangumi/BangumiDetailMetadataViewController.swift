//
//  BangumiDetailMetadataViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SnapKit

extension BangumiDetailMetadataViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch dataSource[indexPath.section] {
        case .titles:
            break
        case .metaData:
            break
        case .onlineDatabases:
            if let data = self.onlineDatabases?[indexPath.row], 
                let url = URL(string: data.url) {
                UIApplication.shared.open(url)
            }
        }
    }
}

extension BangumiDetailMetadataViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch dataSource[section] {
        case .titles:
            return self.titles?.count ?? 0
        case .metaData:
            return self.metaData?.count ?? 0
        case .onlineDatabases:
            return self.onlineDatabases?.count ?? 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch dataSource[indexPath.section] {
        case .titles:
            let cell = tableView.dequeueCell(class: TitleDetailTableViewCell.self, indexPath: indexPath)
            if let data = self.titles?[indexPath.row] {
                cell.titleLabel.text = data.title
                cell.subtitleLabel.text = data.language
            }
            return cell
        case .metaData:
            let cell = tableView.dequeueCell(class: TitleTableViewCell.self, indexPath: indexPath)
            if let data = self.metaData?[indexPath.row] {
                cell.label.text = data
            }
            return cell
        case .onlineDatabases:
            let cell = tableView.dequeueCell(class: TitleDetailTableViewCell.self, indexPath: indexPath)
            if let data = self.onlineDatabases?[indexPath.row] {
                cell.titleLabel.text = data.name
                cell.subtitleLabel.text = data.url
            }
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch dataSource[section] {
        case .titles:
            return NSLocalizedString("标题", comment: "")
        case .metaData:
            return NSLocalizedString("制作信息", comment: "")
        case .onlineDatabases:
            return NSLocalizedString("站外相关链接", comment: "")
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
}

class BangumiDetailMetadataViewController: ViewController {
    
    enum CellType: CaseIterable {
        case titles
        case metaData
        case onlineDatabases
    }
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.registerNibCell(class: TitleTableViewCell.self)
        tableView.registerNibCell(class: TitleDetailTableViewCell.self)
        return tableView
    }()
    
    private var dataSource = CellType.allCases
    
    private var metaData: [String]?
    
    private var titles: [BangumiTitle]?
    
    private var onlineDatabases: [BangumiOnlineDatabase]?
    
    func update(metaData: [String]?, titles: [BangumiTitle]?, onlineDatabases: [BangumiOnlineDatabase]?) {
        self.metaData = metaData
        self.titles = titles
        self.onlineDatabases = onlineDatabases
        self.tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("作品详情", comment: "")

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

}
