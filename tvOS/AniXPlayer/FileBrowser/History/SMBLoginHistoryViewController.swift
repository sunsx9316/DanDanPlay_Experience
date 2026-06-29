//
//  SMBLoginHistoryViewController.swift
//  AniXPlayer
//
//  tvOS SMB 登录历史页面（含 Bonjour 网络邻居发现）
//

import UIKit

class SMBLoginHistoryViewController: RemoteLoginHistoryViewController {

    private let serviceBrowser = SMBServiceBrowser()

    private var discoveredServices: [SMBService] = []

    override var fileManager: FileManagerProtocol {
        return SMBFileManager.shared
    }

    override var fileManagerDesc: String {
        return NSLocalizedString("SMB", comment: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerHeaderFooterView(class: SectionHeaderView.self)
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // SMBServiceBrowser 在 deinit 会自动停止
    }

    private func loadData() {
        self.loginInfos = Preferences.shared.smbLoginInfos ?? []
        tableView.reloadData()
    }

    override func saveData() {
        Preferences.shared.smbLoginInfos = loginInfos
    }

    private func startScanning() {
        serviceBrowser.startScanning { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.discoveredServices = self.serviceBrowser.discoveredServices
                self.tableView.reloadData()
                self.updateEmptyLabel()
            }
        }
    }

    override var isEmpty: Bool {
        return discoveredServices.isEmpty && loginInfos.isEmpty
    }

    override func displayAddress(for loginInfo: LoginInfo) -> String? {
        guard let subPath = loginInfo.parameter?[LoginInfo.Key.smbSubPath.rawValue], !subPath.isEmpty else {
            return loginInfo.url.absoluteString
        }
        var url = loginInfo.url
        url.appendPathComponent(subPath)
        return url.absoluteString
    }

    override func rootFile(for loginInfo: LoginInfo) -> File {
        guard let subPath = loginInfo.parameter?[LoginInfo.Key.smbSubPath.rawValue],
              !subPath.isEmpty else {
            return SMBFile.rootFile
        }

        let parts = subPath.split(separator: "/", maxSplits: 1).map(String.init)
        let shareName = parts[0]
        if parts.count > 1 {
            return SMBFile(shareName: shareName, path: parts[1])
        }
        return SMBFile(shareName: shareName)
    }

    override func connectViewController(loginInfo: LoginInfo?) -> RemoteConnectViewController {
        return SMBConnectViewController(loginInfo: loginInfo)
    }

    // MARK: - Override DataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return discoveredServices.isEmpty ? 1 : 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && !discoveredServices.isEmpty {
            return discoveredServices.count
        }
        return loginInfos.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: FileListCell.self, indexPath: indexPath)

        if indexPath.section == 0 && !discoveredServices.isEmpty {
            let service = discoveredServices[indexPath.row]
            cell.configureAsSource(title: service.name, iconName: "network", detail: service.addressDesc)
        } else {
            let info = loginInfos[indexPath.row]
            let title = displayAddress(for: info) ?? ""
            let detail = displayName(for: info) ?? info.remark ?? ""
            cell.configureAsSource(title: title, iconName: "server.rack", detail: detail)
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && !discoveredServices.isEmpty {
            let service = discoveredServices[indexPath.row]

            if service.addresses.isEmpty {
                connectTo(address: service.name)
                return
            }

            if service.addresses.count == 1 {
                connectTo(address: service.addresses[0].ip)
                return
            }

            let alert = UIAlertController(title: service.name, message: NSLocalizedString("选择一个 IP 地址连接", comment: ""), preferredStyle: .actionSheet)

            for address in service.addresses {
                alert.addAction(.init(title: address.ip, style: .default, handler: { [weak self] _ in
                    self?.connectTo(address: address.ip)
                }))
            }
            alert.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel))

            if let popover = alert.popoverPresentationController {
                popover.sourceView = tableView
                popover.sourceRect = tableView.rectForRow(at: indexPath)
            }
            present(alert, animated: true)
        } else {
            super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }

    private func connectTo(address: String) {
        let urlStr = "smb://\(address)"
        let loginInfo = LoginInfo(url: URL(string: urlStr)!, auth: nil)
        let vc = connectViewController(loginInfo: loginInfo)
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title: String
        if section == 0 && !discoveredServices.isEmpty {
            title = NSLocalizedString("网络邻居", comment: "")
        } else if (section == 0 && discoveredServices.isEmpty) || section == 1 {
            title = NSLocalizedString("登录历史", comment: "")
        } else {
            return nil
        }
        let header = tableView.dequeueHeaderFooterView(class: SectionHeaderView.self)
        header?.title = title
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 55
    }

    override func loginInfoForRow(at indexPath: IndexPath) -> LoginInfo? {
        // 网络邻居段不返回 loginInfo
        if indexPath.section == 0 && !discoveredServices.isEmpty {
            return nil
        }
        return super.loginInfoForRow(at: indexPath)
    }
}
