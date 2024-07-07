//
//  FileBrowserViewController.swift
//  Runner
//
//  Created by jimhuang on 2021/3/7.
//

import UIKit
import SnapKit
import MJRefresh

private class _FileWrapper: NSObject {
    
    let file: File
    
    @objc var name: String {
        return self.file.fileName
    }
    
    var type: FileType {
        return self.file.type
    }
    
    var pathExtension: String {
        return self.file.pathExtension
    }
    
    
    init(file: File) {
        self.file = file
        super.init()
    }
    
}

protocol FileBrowserViewControllerDelegate: AnyObject {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File])
}

extension FileBrowserViewController: UITableViewDelegate, UITableViewDataSource {
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.sortTitleArr.count <= 1 {
            return nil
        }
        return self.sortTitleArr[section]
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if self.sortTitleArr.count <= 1 {
            return nil
        }
        return self.sortTitleArr
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let file = self.dataSource[indexPath.section][indexPath.row].file
        
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
        
        let file = self.dataSource[indexPath.section][indexPath.row].file
        
        switch file.type {
        case .file:
            let files = self.dataSource.flatMap({ $0 }).compactMap({ $0.file }).filter({ $0.type == .file })
            
            self.delegate?.fileBrowserViewController(self, didSelectFile: file, allFiles: files)
        case .folder:
            let vc = FileBrowserViewController(with: file, selectedFile: self.selectedFile, filterType: self.filterType)
            vc.delegate = self
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let file = self.dataSource[indexPath.section][indexPath.row].file
        let cell = tableView.cellForRow(at: indexPath)
        
        if !file.isCanDelete {
            return nil
        }
        
        return .init(actions: [.init(style: .destructive, title: NSLocalizedString("删除", comment: ""), handler: { [weak self] _, _, _ in
            guard let self = self else { return }
            
            self.delete(file: file, from: cell)
        })])
    }
    
    func delete(file: File, from: UIView?) {
        
        let message: String
        
        switch file.type {
        case .folder:
            message = NSLocalizedString("文件夹？", comment: "")
        case .file:
            message = NSLocalizedString("文件？", comment: "")
        }
        
        let vc = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: NSLocalizedString("确定删除此", comment: "") + message, preferredStyle: .alert)
        
        vc.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default, handler: { [weak self] _ in
            
            guard let self = self else { return }
            
            let hud = self.view.showLoading()
            
            type(of: file).fileManager.deleteFile(file) { [weak self] (error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    hud.hide(animated: true)
                    
                    if let error = error {
                        self.view.showError(error)
                        self.tableView.reloadData()
                    } else {
                        self.beginRefreshing()
                    }
                }
            }
        }))
        
        vc.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { [weak self] _ in
            guard let self = self else { return }
            
            self.tableView.reloadData()
        }))
        
        self.present(vc, atView: from)
    }
}

extension FileBrowserViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        self.delegate?.fileBrowserViewController(vc, didSelectFile: didSelectFile, allFiles: allFiles)
    }
}


/// 文件浏览器
class FileBrowserViewController: ViewController {
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: FolderTableViewCell.self)
        tableView.registerClassCell(class: FileTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(beginRefreshing))
        return tableView
    }()
    
    private let manager: FileManagerProtocol
    
    private let rootFile: File
    
    /// 当前选中的文件，用与高亮展示
    private var selectedFile: File?
    
    private(set) var filterType: URLFilterType?
    
    private var dataSource = [[_FileWrapper]]()
    
    private var sortTitleArr = [String]()
    
    private var isShowAllFile = false
    
    weak var delegate: FileBrowserViewControllerDelegate?
    
    
    init(with rootFile: File, selectedFile: File?, filterType: URLFilterType? = nil) {
        self.rootFile = rootFile
        self.selectedFile = selectedFile
        self.filterType = filterType
        self.manager = type(of: rootFile).fileManager
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
        
        let showAllItem = UIBarButtonItem(title: NSLocalizedString("显示全部", comment: ""), target: self, action: #selector(showAllFile(_:)))
        
        self.navigationItem.rightBarButtonItem = showAllItem
        
        self.tableView.mj_header?.beginRefreshing()
    }
    
    //MARK: Private Method
    
    @objc private func showAllFile(_ item: UIBarButtonItem) {
        isShowAllFile.toggle()
        
        if isShowAllFile {
            item.title = NSLocalizedString("恢复默认", comment: "")
        } else {
            item.title = NSLocalizedString("显示全部", comment: "")
        }
        
        self.beginRefreshing()
    }
    
    @objc private func beginRefreshing() {
        self.manager.contentsOfDirectory(at: self.rootFile, filterType: self.isShowAllFile ? nil : self.filterType) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let files):
        
                let tmpIndexedCollation = UILocalizedIndexedCollation.current()
                
                var dataSourceMap = [String: [_FileWrapper]]()
                var dataSourceArr = [[_FileWrapper]]()
                
                
                for file in files {
                    let wrapper = _FileWrapper(file: file)
                    let section = tmpIndexedCollation.section(for: wrapper, collationStringSelector: #selector(getter: _FileWrapper.name))
                    let key = tmpIndexedCollation.sectionIndexTitles[section]
                    if dataSourceMap[key] == nil {
                        dataSourceMap[key] = .init()
                    }
                    dataSourceMap[key]?.append(wrapper)
                }
                
                let sortTitleArr = dataSourceMap.keys.sorted(by: { $0 < $1 })
                
                for key in sortTitleArr {
                    
                    if let sortArr = tmpIndexedCollation.sortedArray(from: dataSourceMap[key] ?? [], collationStringSelector: #selector(getter: _FileWrapper.name)) as? [_FileWrapper] {
                        
                        let tmpArr = sortArr.sorted { f1, f2 in
                            if f1.type == .folder && f2.type == .file {
                                return true
                            } else if f1.type == .file && f2.type == .folder {
                                return false
                            } else {
                                if f1.pathExtension == f2.pathExtension {
                                    return f1.name < f2.name
                                } else {
                                    return f1.pathExtension < f2.pathExtension
                                }
                            }
                        }
                        
                        dataSourceArr.append(tmpArr)
                    }
                }
                
                DispatchQueue.main.async {
                    self.sortTitleArr = sortTitleArr
                    self.dataSource = dataSourceArr
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
