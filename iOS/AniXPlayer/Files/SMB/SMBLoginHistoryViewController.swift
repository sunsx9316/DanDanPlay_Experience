//
//  SMBLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/29.
//

import UIKit

class SMBLoginHistoryViewController: BaseLoginHistoryViewController<SMBFile> {

    private var browser: SMBServiceBrowser?

    override var dataSource: [LoginInfo] {
        get { return Preferences.shared.smbLoginInfos ?? [] }
        set { Preferences.shared.smbLoginInfos = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerClassCell(class: TitleDetailTableViewCell.self)
        startSearch()
    }

    @objc override func beginRefreshing() {
        startSearch()
        super.beginRefreshing()
    }

    override func jumpToConnectViewController(_ loginInfo: LoginInfo? = nil) {
        let vc = SMBConnectViewController(loginInfo: loginInfo, fileManager: SMBFile.fileManager)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }

    override func displayAddress(for loginInfo: LoginInfo) -> String? {
        guard let subPath = loginInfo.parameter?[LoginInfo.Key.smbSubPath.rawValue], !subPath.isEmpty else {
            return loginInfo.url.absoluteString
        }
        var url = loginInfo.url
        url.appendPathComponent(subPath)
        return url.absoluteString
    }

    override func rootFile(for loginInfo: LoginInfo) -> any File {
        // 取得到子路径就拼接，取不到就返回根目录
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

    // MARK: - Network Search

    private func startSearch() {
        self.browser = .init()
        self.browser?.startScanning({ [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        })

        self.tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return self.browser?.discoveredServices.count ?? 0
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueCell(class: TitleDetailTableViewCell.self, indexPath: indexPath)
            let service = self.browser?.discoveredServices[indexPath.row]
            cell.titleLabel.text = service?.name
            cell.subtitleLabel.text = service?.addressDesc
            return cell
        }
        return super.tableView(tableView, cellForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            let service = self.browser?.discoveredServices[indexPath.row]
            let addressModels = service?.addresses ?? []
            if addressModels.count > 1 {
                let vc = UIAlertController(title: NSLocalizedString("请选择地址", comment: ""), message: nil, preferredStyle: .alert)
                for address in addressModels {
                    vc.addAction(UIAlertAction(title: address.ip, style: .default, handler: { [weak self] _ in
                        guard let self = self else { return }

                        guard let url = URL(string: "smb://\(address.ip)") else { return }
                        let loginInfo = LoginInfo(url: url, auth: nil)
                        self.jumpToConnectViewController(loginInfo)
                    }))
                }

                vc.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: nil))
                self.present(vc, atView: tableView.cellForRow(at: indexPath))
            } else if addressModels.count == 1 {
                guard let url = URL(string: "smb://\(addressModels[0].ip)") else { return }
                let loginInfo = LoginInfo(url: url, auth: nil)
                self.jumpToConnectViewController(loginInfo)
            }
        } else {
            super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueHeaderFooterView(class: LinkHistoryHeaderView.self)
        if section == 0 {
            view.titleLabel.text = NSLocalizedString("网络邻居", comment: "")
            let hasUnresolved = self.browser?.discoveredServices.contains(where: { !$0.didResolve }) == true
            if hasUnresolved {
                view.indicatorView.startAnimating()
            } else {
                view.indicatorView.stopAnimating()
            }
        } else {
            view.titleLabel.text = NSLocalizedString("登陆历史", comment: "")
            view.indicatorView.stopAnimating()
        }
        return view
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.section == 0 {
            return nil
        }
        return super.tableView(tableView, trailingSwipeActionsConfigurationForRowAt: indexPath)
    }
}
