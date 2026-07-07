//
//  UserInfoViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/13.
//

import UIKit
import SnapKit
import Kingfisher

class UserInfoViewController: ViewController {

    private enum Section: Int, CaseIterable {
        case userInfo
        case menu
    }

    private enum MenuItem: Int, CaseIterable {
        case settings
        case about

        var title: String {
            switch self {
            case .settings: return NSLocalizedString("设置", comment: "")
            case .about:
                return NSLocalizedString("关于", comment: "") + " " + AppInfoHelper.appDisplayName
            }
        }
    }

    private let menuItems = MenuItem.allCases

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: UserInfoCell.self)
        tv.registerClassCell(class: SeparatorTableViewCell.self)
        tv.separatorStyle = .none
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("我的", comment: "")
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    private func showLogin() {
        let vc = LoginViewController()
        vc.hidesBottomBarWhenPushed = true
        vc.didLoginCallBack = { [weak self] vc, info in
            guard let self = self else { return }
            vc.navigationController?.popViewController(animated: true)
            self.view.showHUD(NSLocalizedString("登录成功！", comment: ""))
            Preferences.shared.loginInfo = info
            self.tableView.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showSettings() {
        let vc = SettingViewController()
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showAbout() {
        let vc = AboutViewController()
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    private func logout() {
        Preferences.shared.loginInfo = nil
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension UserInfoViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = Section(rawValue: section) else { return 0 }
        switch sec {
        case .userInfo: return 1
        case .menu: return menuItems.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sec = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        switch sec {
        case .userInfo:
            let cell = tableView.dequeueCell(class: UserInfoCell.self, indexPath: indexPath)
            cell.showSeparator = false
            if let userInfo = Preferences.shared.loginInfo {
                cell.configure(avatarURL: URL(string: userInfo.profileImage), username: userInfo.screenName)
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.configure(avatarURL: nil, username: NSLocalizedString("点击登录", comment: ""))
                cell.accessoryType = .none
            }
            return cell

        case .menu:
            let item = menuItems[indexPath.row]
            let cell = tableView.dequeueCell(class: SeparatorTableViewCell.self, indexPath: indexPath)
            cell.textLabel?.text = item.title
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension UserInfoViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let sec = Section(rawValue: indexPath.section) else { return 0 }
        switch sec {
        case .userInfo: return 100
        case .menu: return 50
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNonzeroMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sec = Section(rawValue: indexPath.section) else { return }
        switch sec {
        case .userInfo:
            if Preferences.shared.loginInfo != nil {
                let alert = UIAlertController(title: nil, message: NSLocalizedString("确定退出登录吗？", comment: ""), preferredStyle: .alert)
                alert.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: nil))
                alert.addAction(.init(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { [weak self] _ in
                    self?.logout()
                }))
                self.present(alert, animated: true)
            } else {
                showLogin()
            }
        case .menu:
            switch menuItems[indexPath.row] {
            case .settings:
                showSettings()
            case .about:
                showAbout()
            }
        }
    }
}
