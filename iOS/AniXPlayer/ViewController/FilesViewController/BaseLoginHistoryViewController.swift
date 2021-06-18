//
//  WebDavLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/6.
//

import UIKit

extension BaseLoginHistoryViewController: BaseConnectSvrViewControllerDelegate {
    func viewControllerDidSuccessConnected(_ viewController: BaseConnectSvrViewController, loginInfo: LoginInfo) {
        
        var loginInfos = self.dataSource
        
        if !loginInfos.contains(where: { $0 == loginInfo }) {
            loginInfos.append(loginInfo)
            self.dataSource = loginInfos
            self.historyLoginInfos = loginInfos
            self.tableView.reloadData()
        }
        
        let rootFile = F.rootFile
        let vc = FileBrowserViewController(with: rootFile, selectedFile: nil, filterType: .video)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

extension BaseLoginHistoryViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        let nvc = PlayerNavigationController(items: allFiles, selectedItem: didSelectFile)
        self.present(nvc, animated: true, completion: nil)
    }
}

class BaseLoginHistoryViewController<F: File>: ViewController, UITableViewDelegate, UITableViewDataSource {
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: LinkHistoryTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.tableHeaderView = UIView(frame: .init(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.registerClassHeaderFooterView(class: LinkHistoryHeaderView.self)
        tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(beginRefreshing))
        return tableView
    }()
    
    private lazy var historyLoginInfos: [LoginInfo] = {
        return self.dataSource
    }()
    
    var dataSource: [LoginInfo] {
        get {
            assert(false, "must override")
            return []
        }
        
        set {
            assert(false, "must override")
            self.dataSource = newValue
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = F.rootFile.fileManager.desc
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        let rightBarButtonItem = UIBarButtonItem(imageName: "Public/add", target: self, action: #selector(onTouchAddButton))
        self.navigationItem.rightBarButtonItem = rightBarButtonItem
        
        self.beginRefreshing()
    }
    
    //MARK: Private Method
    @objc private func beginRefreshing() {
        self.historyLoginInfos = self.dataSource
        self.tableView.mj_header?.endRefreshing()
    }
    
    @objc private func onTouchAddButton() {
        self.jumpToConnectViewController()
    }
    
    private func jumpToConnectViewController(_ loginInfo: LoginInfo? = nil) {
        let vc = BaseConnectSvrViewController(loginInfo: loginInfo, fileManager: F.rootFile.fileManager)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func deleteLoginInfo(_ info: LoginInfo, at view: UIView?) {
        let message = String(format: NSLocalizedString("确定删除%@吗？", comment: ""), info.url.host ?? "")
        let vc = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: message, preferredStyle: .alert)
        vc.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { action in
            var smbLoginInfos = self.dataSource
            if smbLoginInfos.contains(info) {
                smbLoginInfos.removeAll(where: { $0 == info })
                self.dataSource = smbLoginInfos
                self.historyLoginInfos = smbLoginInfos
                self.tableView.reloadData()
            }
        }))

        vc.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { action in
            self.tableView.reloadData()
        }))
        vc.popoverPresentationController?.sourceView = view
        self.present(vc, animated: true, completion: nil)
    }
    
    //MARK: UITableViewDelegate, UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.historyLoginInfos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueCell(class: LinkHistoryTableViewCell.self, indexPath: indexPath)
        let info = self.historyLoginInfos[indexPath.row]
        cell.titleLabel.text = info.url.host
        cell.addressLabel.text = info.auth?.userName
        cell.indicatorView.stopAnimating()
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
 
        let loginInfo = self.historyLoginInfos[indexPath.row]
        self.jumpToConnectViewController(loginInfo)
        
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueHeaderFooterView(class: LinkHistoryHeaderView.self)
        view.titleLabel.text = NSLocalizedString("登陆历史", comment: "")
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNonzeroMagnitude
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let config = UISwipeActionsConfiguration(actions: [UIContextualAction(style: .destructive, title: NSLocalizedString("删除", comment: ""), handler: { [weak self] (_, _, _) in
            guard let self = self else { return }
            
            self.deleteLoginInfo(self.historyLoginInfos[indexPath.row], at: tableView.cellForRow(at: indexPath))
        })])
        return config
    }
}
