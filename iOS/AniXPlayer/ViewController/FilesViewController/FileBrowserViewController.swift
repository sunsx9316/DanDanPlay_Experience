//
//  FileBrowserViewController.swift
//  Runner
//
//  Created by jimhuang on 2021/3/7.
//

import UIKit
import SnapKit
import MJRefresh

protocol FileBrowserViewControllerDelegate: AnyObject {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File])
}

extension FileBrowserViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let file = self.dataSource[indexPath.row]
        
        switch file.type {
        case .file:
            let cell = tableView.dequeueCell(class: FileTableViewCell.self, indexPath: indexPath)
            cell.file = file
            if file.url == self.selectedFile?.url {
                cell.backgroundView?.backgroundColor = .headViewBackgroundColor
            } else {
                cell.backgroundView?.backgroundColor = .backgroundColor
            }
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
            let files = self.dataSource.filter({ $0.type == .file })
            self.delegate?.fileBrowserViewController(self, didSelectFile: file, allFiles: files)
        case .folder:
            let vc = FileBrowserViewController(with: file, selectedFile: self.selectedFile, filterType: self.filterType)
            vc.delegate = self
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension FileBrowserViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        self.delegate?.fileBrowserViewController(vc, didSelectFile: didSelectFile, allFiles: allFiles)
    }
}


/// 文件浏览器
class FileBrowserViewController: ViewController {
    
    struct FilterType: OptionSet {
        let rawValue: Int
        
        static let video = FilterType(rawValue: 1 << 0)
        static let subtitle = FilterType(rawValue: 1 << 1)
        static let danmaku = FilterType(rawValue: 1 << 2)
        
        static let all: FilterType = [.video, .subtitle, .danmaku]
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
    
    private let rootFile: File
    
    private var selectedFile: File?
    
    private(set) var filterType: FilterType?
    
    private var dataSource = [File]()
    
    weak var delegate: FileBrowserViewControllerDelegate?
    
    
    init(with rootFile: File, selectedFile: File?, filterType: FilterType? = nil) {
        self.rootFile = rootFile
        self.selectedFile = selectedFile
        self.filterType = filterType
        self.manager = rootFile.fileManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.rootFile.fileName
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        self.tableView.mj_header?.beginRefreshing()
    }
    
    private func isThisType(_ url: URL) -> Bool {
        guard let filterType = self.filterType else { return true }
        
        if url.isMediaFile {
            return filterType.contains(.video)
        }
        
        if url.isDanmakuFile {
            return filterType.contains(.danmaku)
        }
        
        if url.isSubtitleFile {
            return filterType.contains(.subtitle)
        }
        
        return false
    }
    
    @objc private func beginRefreshing() {
        self.manager.contentsOfDirectory(at: self.rootFile) { [weak self] result in
            guard let self = self else { return }
            
                switch result {
                case .success(let files):
                    
                    var filterFiles = files.filter { file in
                        if file.type == .file {
                            return self.isThisType(file.url)
                        } else {
                            return true
                        }
                    }
                    
                    filterFiles.sort { f1, f2 in
                        if f1.type == .folder && f2.type == .file {
                            return true
                        } else if f1.type == .file && f2.type == .folder {
                            return false
                        } else {
                            if f1.pathExtension == f2.pathExtension {
                                return f1.url.absoluteString < f2.url.absoluteString
                            } else {
                                return f1.pathExtension < f2.pathExtension
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.dataSource = filterFiles
                        self.tableView.mj_header?.endRefreshing()
                        self.tableView.reloadData()
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.view.showError(error)
                        self.tableView.mj_header?.endRefreshing()
                        self.tableView.reloadData()
                    }
            }
        }
    }

}
