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
            return self.services.count
        }
        return self.historyLoginInfos.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueCell(class: LinkHistoryTableViewCell.self, indexPath: indexPath)
        if indexPath.section == 0 {
            let service = self.services[indexPath.row]
            
            cell.titleLabel.text = service.name
            cell.addressLabel.text = service.addressDesc
            
            if service.didResolve {
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
            let service = self.services[indexPath.row]
            let addressModels = service.netService?.addressModels ?? []
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
                vc.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
                self.present(vc, animated: true, completion: nil)
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

extension SMBLoginHistoryViewController: NetServiceBrowserDelegate {
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        debugPrint("netServiceBrowserWillSearch")
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        debugPrint("netServiceBrowserDidStopSearch")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        debugPrint("didNotSearch \(errorDict)")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        service.resolve(withTimeout: 5)
        DispatchQueue.main.async {
            self.services.append(Service(netService: service))
            self.tableView.reloadData()
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        DispatchQueue.main.async {
            self.services.removeAll(where: { $0.netService == service })
            self.tableView.reloadData()
        }
    }
}

extension SMBLoginHistoryViewController: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        DispatchQueue.main.async {
            let service = self.services.first(where: { $0.netService == sender })
            service?.didResolve = true
            self.tableView.reloadData()
        }
    }
}

extension SMBLoginHistoryViewController: SMBConnectViewControllerDelegate {
    func viewControllerDidSuccessConnected(_ viewController: SMBConnectViewController, loginInfo: LoginInfo) {
        
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
    
    private class Service {
        private(set) var netService: NetService?
        
        var didResolve = false
        
        var addressDesc: String? {
            let addressModels = self.netService?.addressModels
            let str = addressModels?.reduce("", { res, model in
                return res + model.address + (model == addressModels?.last ? "" : "\n")
            })
            return str
        }
        
        var name: String? {
            return self.netService?.name
        }
        
        init(netService: NetService) {
            self.netService = netService
        }
    }
    
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
    
    private lazy var services = [Service]()
    
    private lazy var netServiceBrowser: NetServiceBrowser = {
        let browser = NetServiceBrowser()
        browser.delegate = self
        return browser
    }()
    
    
    deinit {
        self.netServiceBrowser.stop()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "SMB"
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        let rightBarButtonItem = UIBarButtonItem(imageName: "File/file_add_file", target: self, action: #selector(onTouchAddButton))
        
        self.navigationItem.rightBarButtonItem = rightBarButtonItem
        
        self.beginRefreshing()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.stopSearch()
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
        let vc = SMBConnectViewController(loginInfo: loginInfo, fileManager: SMBFile.rootFile.fileManager)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func startSeach() {
        self.netServiceBrowser.stop()
        self.netServiceBrowser.searchForServices(ofType: "_smb._tcp.", inDomain: "local.")
        self.services.removeAll()
        self.tableView.reloadData()
    }
    
    private func stopSearch() {
        self.netServiceBrowser.stop()
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
        vc.popoverPresentationController?.sourceView = view
        self.present(vc, animated: true, completion: nil)
    }
    
}
