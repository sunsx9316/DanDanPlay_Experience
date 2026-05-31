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

    override var fileManagerDesc: String {
        return NSLocalizedString("SMB", comment: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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

    override func rootFile(for loginInfo: LoginInfo) -> File {
        return SMBFile.rootFile
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
        let cell = tableView.dequeueReusableCell(withIdentifier: FileListCell.reuseIdentifier, for: indexPath) as! FileListCell

        if indexPath.section == 0 && !discoveredServices.isEmpty {
            let service = discoveredServices[indexPath.row]
            cell.configureAsSource(title: service.name, iconName: "network")
        } else {
            let info = loginInfos[indexPath.row]
            let title = info.url.host ?? info.url.absoluteString
            let detail = info.remark ?? info.auth?.userName ?? ""
            cell.configureAsSource(title: title, iconName: "server.rack", detail: detail)
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && !discoveredServices.isEmpty {
            let service = discoveredServices[indexPath.row]
            let address = service.addresses.first ?? service.name
            let loginInfo = LoginInfo(url: URL(string: "smb://\(address)")!, auth: nil)
            connect(with: loginInfo)
        } else {
            super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && !discoveredServices.isEmpty {
            return NSLocalizedString("网络邻居", comment: "")
        } else if (section == 0 && discoveredServices.isEmpty) || section == 1 {
            return NSLocalizedString("登录历史", comment: "")
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // 网络邻居段不支持删除
        if indexPath.section == 0 && !discoveredServices.isEmpty {
            return false
        }
        return true
    }
}
