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

    func numberOfSections(in tableView: UITableView) -> Int {
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
            let cell = tableView.dequeueCell(class: LinkHistoryTableViewCell.self, indexPath: indexPath)
            let service = self.browser?.discoveredServices[indexPath.row]

            cell.titleLabel.text = service?.name
            cell.addressLabel.text = service?.addressDesc

            if service?.didResolve == true {
                cell.indicatorView.stopAnimating()
            } else {
                cell.indicatorView.startAnimating()
            }
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
                    vc.addAction(UIAlertAction(title: address, style: .default, handler: { [weak self] _ in
                        guard let self = self else { return }

                        let loginInfo = LoginInfo(url: URL(string: "smb://\(address)")!, auth: nil)
                        self.jumpToConnectViewController(loginInfo)
                    }))
                }

                vc.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: nil))
                self.present(vc, atView: tableView.cellForRow(at: indexPath))
            } else if addressModels.count == 1 {
                let loginInfo = LoginInfo(url: URL(string: "smb://\(addressModels[0])")!, auth: nil)
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
        } else {
            view.titleLabel.text = NSLocalizedString("登陆历史", comment: "")
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
