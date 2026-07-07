//
//  AboutViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/29.
//

import UIKit
import SnapKit

class AboutViewController: ViewController {

    private let projectURL = "https://github.com/sunsx9316/DanDanPlay_Experience"

    private lazy var headerView: UIView = {
        let view = UIView()

        let iconView = UIImageView()
        iconView.image = Self.appIcon
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 16
        iconView.clipsToBounds = true
        view.addSubview(iconView)

        let nameLabel = Label()
        nameLabel.text = AppInfoHelper.appDisplayName
        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textAlignment = .center
        view.addSubview(nameLabel)

        let versionLabel = Label()
        versionLabel.text = "v\(AppInfoHelper.appVersion) (\(AppInfoHelper.buildNumber))"
        versionLabel.font = .systemFont(ofSize: 14)
        versionLabel.textColor = .secondaryLabel
        versionLabel.textAlignment = .center
        view.addSubview(versionLabel)

        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(30)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(80)
        }

        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
        }

        versionLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }

        return view
    }()

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: SeparatorTableViewCell.self)
        tv.rowHeight = 50
        tv.separatorStyle = .none
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("关于", comment: "")

        let headerContainer = UIView()
        headerContainer.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let headerSize = headerView.systemLayoutSizeFitting(
            CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        headerContainer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: headerSize.height)
        tableView.tableHeaderView = headerContainer

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let header = tableView.tableHeaderView {
            let size = header.systemLayoutSizeFitting(
                CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            if header.frame.height != size.height {
                header.frame.size.height = size.height
                tableView.tableHeaderView = header
            }
        }
    }

    // MARK: - App Icon

    private static var appIcon: UIImage? {
        guard let name = AppInfoHelper.appIconName else { return nil }
        return UIImage(named: name)
    }
}

extension AboutViewController: UITableViewDataSource {

    private enum Row: Int, CaseIterable {
        case openSource
        case project

        var title: String {
            switch self {
            case .openSource: return NSLocalizedString("开源组件", comment: "")
            case .project: return NSLocalizedString("项目开源地址", comment: "")
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: SeparatorTableViewCell.self, indexPath: indexPath)
        cell.textLabel?.text = Row(rawValue: indexPath.row)?.title
        cell.textLabel?.font = .systemFont(ofSize: 16)
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

extension AboutViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNonzeroMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let row = Row(rawValue: indexPath.row) else { return }
        switch row {
        case .openSource:
            let vc = OpenSourceListViewController()
            navigationController?.pushViewController(vc, animated: true)
        case .project:
            guard let url = URL(string: projectURL) else { return }
            UIApplication.shared.open(url)
        }
    }
}
