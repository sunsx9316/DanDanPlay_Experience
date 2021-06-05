//
//  FilesViewController.swift
//  Runner
//
//  Created by jimhuang on 2021/3/7.
//

import UIKit
import SnapKit
import MJRefresh

protocol FilesViewControllerDelegate: AnyObject {
    func filesViewController(_ vc: FilesViewController, didSelectFile: File)
}

extension FilesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let file = self.dataSource[indexPath.row]
        
        switch file.type {
        case .file:
            let cell = tableView.dequeueCell(class: FileTableViewCell.self, indexPath: indexPath)
            cell.file = file
            return cell
        case .folder:
            let cell = tableView.dequeueCell(class: FolderTableViewCell.self, indexPath: indexPath)
            cell.file = file
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let file = self.dataSource[indexPath.row]
        
        switch file.type {
        case .file:
            self.delegate?.filesViewController(self, didSelectFile: file)
        case .folder:
            let vc = FilesViewController(with: file, filterType: self.filterType)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}


class FilesViewController: ViewController {
    
    enum FilterType: Int {
        case none
        case video
        case subtitle
        case danmaku
    }
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: FolderTableViewCell.self)
        tableView.registerNibCell(class: FileTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(beginRefreshing))
        return tableView
    }()
    
    private let manager: FileManagerProtocol
    
    private let url: URL
    
    private var filterType: FilterType?
    
    private var dataSource = [File]()
    
    weak var delegate: FilesViewControllerDelegate?
    
    
    init(with file: File, filterType: FilterType? = nil) {
        switch file.type {
        case .folder:
            self.url = file.url
        case .file:
            self.url = file.url.deletingLastPathComponent()
        }
        
        self.filterType = filterType
        self.manager = file.fileManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.url.lastPathComponent
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        self.beginRefreshing()
    }
    
    @objc private func beginRefreshing() {
        self.manager.contentsOfDirectory(at: self.url) { [weak self] (files) in
            guard let self = self else { return }
            
            self.dataSource = files
            self.tableView.mj_header?.endRefreshing()
            self.tableView.reloadData()
        }
    }

}
