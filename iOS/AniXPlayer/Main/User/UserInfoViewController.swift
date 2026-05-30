//
//  UserInfoViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/13.
//

import UIKit
import SnapKit
import SVGKit
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
                let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
                    ?? "AniXPlayer"
                return NSLocalizedString("关于", comment: "") + " " + appName
            }
        }
    }

    private let menuItems = MenuItem.allCases

    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 40
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.mainColor.cgColor
        return imageView
    }()

    private lazy var usernameLabel: UILabel = {
        let label = Label()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.numberOfLines = 0
        return label
    }()

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.register(SeparatorTableViewCell.self, forCellReuseIdentifier: "UserInfoCell")
        tv.register(SeparatorTableViewCell.self, forCellReuseIdentifier: "MenuCell")
        tv.rowHeight = 50
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
        reloadData()
    }

    private func reloadData() {
        if let userInfo = Preferences.shared.loginInfo {
            avatarImageView.kf.setImage(with: URL(string: userInfo.profileImage), placeholder: defaultAvatar())
            usernameLabel.text = userInfo.screenName
        } else {
            avatarImageView.image = defaultAvatar()
            usernameLabel.text = NSLocalizedString("点击登录", comment: "")
        }
        tableView.reloadData()
    }

    private func defaultAvatar() -> UIImage? {
        if let svgImage = SVGKImage(named: "User.svg", withCacheKey: "User.svg") {
            svgImage.size = CGSize(width: 80, height: 80)
            return svgImage.uiImage.byInsetEdge(UIEdgeInsets(top: -20, left: -20, bottom: -20, right: -20), with: nil)
        }
        return nil
    }

    private func showLogin() {
        let vc = LoginViewController()
        vc.hidesBottomBarWhenPushed = true
        vc.didLoginCallBack = { [weak self] vc, info in
            guard let self = self else { return }
            vc.navigationController?.popViewController(animated: true)
            self.view.showHUD(NSLocalizedString("登录成功！", comment: ""))
            Preferences.shared.loginInfo = info
            self.reloadData()
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
        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(80)
        }
        usernameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(16)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserInfoCell", for: indexPath) as! SeparatorTableViewCell
            configureUserInfoCell(cell)
            cell.showSeparator = false
            cell.accessoryType = Preferences.shared.loginInfo != nil ? .disclosureIndicator : .none
            return cell

        case .menu:
            let item = menuItems[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "MenuCell", for: indexPath) as! SeparatorTableViewCell
            cell.textLabel?.text = item.title
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension UserInfoViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .userInfo: return 100
        case .menu: return 50
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 20 : 20
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNonzeroMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
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
