//
//  UserInfoViewController.swift
//  AniXPlayer
//
//  tvOS "我的" 页面 — 用户信息 + 设置入口
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
        case logout

        var title: String {
            switch self {
            case .settings: return NSLocalizedString("设置", comment: "")
            case .logout: return NSLocalizedString("退出登录", comment: "")
            }
        }
    }

    private var menuItems: [MenuItem] {
        let isLogin = Preferences.shared.loginInfo != nil
        return isLogin ? [.settings, .logout] : [.settings]
    }

    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 40
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        iv.snp.makeConstraints { make in make.width.height.equalTo(80) }
        return iv
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.font = .ddp_normal(weight: .bold)
        label.textColor = .label
        return label
    }()

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(TableViewCell.self, forCellReuseIdentifier: "UserInfoCell")
        tv.register(TableViewCell.self, forCellReuseIdentifier: "MenuCell")
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
        if let userInfo = Preferences.shared.loginInfo {
            usernameLabel.text = userInfo.screenName
            if let url = URL(string: userInfo.profileImage) {
                avatarImageView.kf.setImage(with: url)
            }
        } else {
            usernameLabel.text = NSLocalizedString("点击登录", comment: "")
            avatarImageView.kf.cancelDownloadTask()
            avatarImageView.image = nil
        }
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

    private var configuredUserInfoCell: UITableViewCell?

    private func configureUserInfoCell(_ cell: UITableViewCell) {
        guard configuredUserInfoCell !== cell else { return }
        configuredUserInfoCell = cell
        avatarImageView.removeFromSuperview()
        usernameLabel.removeFromSuperview()
        cell.contentView.addSubview(avatarImageView)
        cell.contentView.addSubview(usernameLabel)
        avatarImageView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(40)
            make.centerY.equalToSuperview()
        }
        usernameLabel.snp.remakeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(20)
            make.centerY.equalToSuperview()
        }
    }
}

// MARK: - UITableViewDataSource

extension UserInfoViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .userInfo: return 1
        case .menu: return menuItems.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .userInfo:
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserInfoCell", for: indexPath)
            configureUserInfoCell(cell)
            return cell

        case .menu:
            let item = menuItems[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "MenuCell", for: indexPath)
            cell.textLabel?.text = item.title
            cell.textLabel?.font = .ddp_normal()
            cell.textLabel?.textColor = .label
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension UserInfoViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .userInfo: return 120
        case .menu: return 66
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
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
