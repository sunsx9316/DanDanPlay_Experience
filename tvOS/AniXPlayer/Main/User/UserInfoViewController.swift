//
//  UserInfoViewController.swift
//  AniXPlayer
//
//  tvOS "我的" 页面 — 用户信息 + 设置入口
//

import UIKit
import SnapKit

class UserInfoViewController: ViewController {

    private enum Section: Int, CaseIterable {
        case userInfo
        case menu
    }

    private enum MenuItem: Int, CaseIterable {
        case settings
        case logout

        var title: String {
            switch self {
            case .settings: return NSLocalizedString("设置", comment: "")
            case .logout: return NSLocalizedString("退出登录", comment: "")
            }
        }

        var icon: UIImage? {
            switch self {
            case .settings: return UIImage(systemName: "gearshape.fill")
            case .logout: return UIImage(systemName: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private var menuItems: [MenuItem] {
        let isLogin = Preferences.shared.loginInfo != nil
        return isLogin ? [.settings, .logout] : [.settings]
    }

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: UserInfoCell.self)
        tv.registerClassCell(class: MenuCell.self)
        tv.rowHeight = 66
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
        reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defaultFocusView = tableView
    }

    private func reloadData() {
        tableView.reloadData()
    }

    private func showLogin() {
        let vc = LoginViewController()
        vc.didLoginCallBack = { [weak self] _, _ in
            self?.navigationController?.popViewController(animated: true)
            self?.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showSettings() {
        let vc = SettingViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func logout() {
        Preferences.shared.loginInfo = nil
        reloadData()
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
            if let userInfo = Preferences.shared.loginInfo {
                cell.configure(avatarURL: URL(string: userInfo.profileImage), username: userInfo.screenName)
            } else {
                cell.configure(avatarURL: nil, username: NSLocalizedString("点击登录", comment: ""))
            }
            return cell

        case .menu:
            let item = menuItems[indexPath.row]
            let cell = tableView.dequeueCell(class: MenuCell.self, indexPath: indexPath)
            cell.configure(icon: item.icon, title: item.title)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension UserInfoViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let sec = Section(rawValue: indexPath.section) else { return 0 }
        switch sec {
        case .userInfo: return 120
        case .menu: return 66
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sec = Section(rawValue: indexPath.section) else { return }
        switch sec {
        case .userInfo:
            if Preferences.shared.loginInfo == nil {
                showLogin()
            }
        case .menu:
            switch menuItems[indexPath.row] {
            case .settings:
                showSettings()
            case .logout:
                logout()
            }
        }
    }
}
