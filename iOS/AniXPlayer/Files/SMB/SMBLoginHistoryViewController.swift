//
//  SMBLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/29.
//

import UIKit

private extension AddressModel {
    var loginInfo: LoginInfo? {
        if let url = URL(string: "smb://\(self.address)") {
            return LoginInfo(url: url, auth: nil)
        }
        return nil
    }
}

extension SMBLoginHistoryViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return self.browser?.discoveredServices.count ?? 0
        }
        return self.historyLoginInfos.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueCell(class: LinkHistoryTableViewCell.self, indexPath: indexPath)
        if indexPath.section == 0 {
            let service = self.browser?.discoveredServices[indexPath.row]
            
            cell.titleLabel.text = service?.name
            cell.addressLabel.text = service?.addressDesc
            
            if service?.didResolve == true {
                cell.indicatorView.stopAnimating()
            } else {
                cell.indicatorView.startAnimating()
            }
        } else {
            let info = self.historyLoginInfos[indexPath.row]
            cell.titleLabel.text = info.url.host
            cell.addressLabel.text = info.auth?.userName
            cell.indicatorView.stopAnimating()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
 
        if indexPath.section == 0 {
            let service = self.browser?.discoveredServices[indexPath.row]
            let addressModels = service?.addresses ?? []
            if addressModels.count > 1 {
                let vc = UIAlertController(title: NSLocalizedString("请选择地址", comment: ""), message: nil, preferredStyle: .alert)
                for address in addressModels {
                    vc.addAction(UIAlertAction(title: address.address, style: .default, handler: { [weak self] _ in
                        guard let self = self else { return }
                        
                        let loginInfo = address.loginInfo
                        self.jumpToConnectViewController(loginInfo)
                    }))
                }
                
                vc.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: nil))
                self.present(vc, atView: tableView.cellForRow(at: indexPath))
            } else if (addressModels.count == 1) {
                let loginInfo = addressModels[0].loginInfo
                self.jumpToConnectViewController(loginInfo)
            }
        } else {
            let loginInfo = self.historyLoginInfos[indexPath.row]
            self.jumpToConnectViewController(loginInfo)
        }
        
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueHeaderFooterView(class: LinkHistoryHeaderView.self)
        if section == 0 {
            view.titleLabel.text = NSLocalizedString("网络邻居", comment: "")
        } else {
            view.titleLabel.text = NSLocalizedString("登陆历史", comment: "")
        }
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNonzeroMagnitude
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.section == 0 {
            return nil
        }
        
        let config = UISwipeActionsConfiguration(actions: [UIContextualAction(style: .destructive, title: NSLocalizedString("删除", comment: ""), handler: { [weak self] (_, _, _) in
            guard let self = self else { return }
            
            self.deleteLoginInfo(self.historyLoginInfos[indexPath.row], at: tableView.cellForRow(at: indexPath))
        })])
        return config
    }
    
}

extension SMBLoginHistoryViewController: BaseConnectSvrViewControllerDelegate {
    func viewControllerDidSuccessConnected(_ viewController: ViewController, loginInfo: LoginInfo) {
        
        var loginInfos = Preferences.shared.smbLoginInfos ?? []
        
        if !loginInfos.contains(where: { $0 == loginInfo }) {
            loginInfos.append(loginInfo)
            Preferences.shared.smbLoginInfos = loginInfos
            self.historyLoginInfos = loginInfos
            self.tableView.reloadData()
        }
        
        let rootFile = SMBFile.rootFile
        let vc = FileBrowserViewController(with: rootFile, selectedFile: nil, filterType: .video)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

extension SMBLoginHistoryViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        let nvc = PlayerNavigationController(items: allFiles, selectedItem: didSelectFile)
        self.present(nvc, animated: true, completion: nil)
    }
}

class SMBLoginHistoryViewController: ViewController {
    
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
        return Preferences.shared.smbLoginInfos ?? []
    }()
    
    private var browser: SMBServiceBrowser?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "SMB"
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        let rightBarButtonItem = UIBarButtonItem(imageName: "Public/add", target: self, action: #selector(onTouchAddButton))
        
        self.navigationItem.rightBarButtonItem = rightBarButtonItem
        
        self.beginRefreshing()
    }
    
    @objc private func beginRefreshing() {
        self.startSeach()
        self.historyLoginInfos = Preferences.shared.smbLoginInfos ?? []
        self.tableView.mj_header?.endRefreshing()
    }
    
    @objc private func onTouchAddButton() {
        self.jumpToConnectViewController()
    }
    
    private func jumpToConnectViewController(_ loginInfo: LoginInfo? = nil) {
        let vc = SMBConnectViewController(loginInfo: loginInfo, fileManager: SMBFile.fileManager)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func startSeach() {
        self.browser = .init()
        self.browser?.startScanning({ [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        })
        
        self.tableView.reloadData()
    }
    
    private func stopSearch() {
        self.browser = nil
    }
    
    private func deleteLoginInfo(_ info: LoginInfo, at view: UIView?) {
        let message = String(format: NSLocalizedString("确定删除%@吗？", comment: ""), info.url.host ?? "")
        let vc = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: message, preferredStyle: .alert)
        vc.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { action in
            var smbLoginInfos = Preferences.shared.smbLoginInfos ?? []
            if smbLoginInfos.contains(info) {
                smbLoginInfos.removeAll(where: { $0 == info })
                Preferences.shared.smbLoginInfos = smbLoginInfos
                self.historyLoginInfos = smbLoginInfos
                self.tableView.reloadData()
            }
        }))

        vc.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { action in
            self.tableView.reloadData()
        }))
        self.present(vc, atView: view)
    }
    
}
