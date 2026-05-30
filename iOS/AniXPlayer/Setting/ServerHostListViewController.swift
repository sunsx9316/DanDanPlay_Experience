//
//  ServerHostListViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/4/14.
//

import UIKit
import SnapKit
import RxSwift

extension ServerHostListViewController: UITableViewDelegate, UITableViewDataSource {

    enum Section: Int, CaseIterable {
        case official
        case custom
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .official:
            // 默认域名 + 备用域名
            return 1 + (self.backupHosts?.count ?? 0)
        case .custom:
            return self.customHosts?.count ?? 0
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionType = Section(rawValue: section) else { return nil }

        switch sectionType {
        case .official:
            let headerView = ServerHostSectionHeaderView()
            headerView.configure(title: NSLocalizedString("官方域名", comment: ""), showRefreshButton: true)
            headerView.onRefresh = { [weak self] in
                self?.loadBackupHosts()
            }
            return headerView
        case .custom:
            let headerView = ServerHostSectionHeaderView()
            headerView.configure(title: NSLocalizedString("自定义域名", comment: ""), showRefreshButton: false)
            return headerView
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: TitleTableViewCell.self, indexPath: indexPath)

        guard let sectionType = Section(rawValue: indexPath.section) else { return cell }

        switch sectionType {
        case .official:
            if indexPath.row == 0 {
                cell.label.text = DefaultHost
                cell.label.textColor = self.currentHost == DefaultHost ? .mainColor : .textColor
            } else {
                let backupIndex = indexPath.row - 1
                if let backupHost = self.backupHosts?[backupIndex] {
                    cell.label.text = backupHost
                    cell.label.textColor = self.currentHost == backupHost ? .mainColor : .textColor
                }
            }
            cell.accessoryType = .none
            cell.selectionStyle = .default
        case .custom:
            if let host = self.customHosts?[indexPath.row] {
                cell.label.text = host
                cell.label.textColor = self.currentHost == host ? .mainColor : .textColor
            }
            cell.accessoryType = .none
            cell.selectionStyle = .default
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let sectionType = Section(rawValue: indexPath.section) else { return }

        var selectedHost: String?

        switch sectionType {
        case .official:
            if indexPath.row == 0 {
                selectedHost = DefaultHost
            } else {
                let backupIndex = indexPath.row - 1
                selectedHost = self.backupHosts?[backupIndex]
            }
        case .custom:
            selectedHost = self.customHosts?[indexPath.row]
        }

        if let host = selectedHost {
            self.globalSettingModel.onChangeHost(host)
            self.navigationController?.popViewController(animated: true)
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return Section(rawValue: indexPath.section) == .custom
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard var hosts = self.customHosts else { return }

            // 如果删除的是当前使用的自定义域名，恢复为默认域名
            let deletedHost = hosts[indexPath.row]
            if deletedHost == self.currentHost {
                self.globalSettingModel.onChangeHost(DefaultHost)
            }

            hosts.remove(at: indexPath.row)
            Preferences.shared.customHosts = hosts

            tableView.performBatchUpdates {
                self.customHosts = hosts
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        }
    }
}

// MARK: - ServerHostSectionHeaderView

class ServerHostSectionHeaderView: TitleTableViewHeaderFooterView {

    var onRefresh: (() -> Void)?

    private lazy var refreshButton: Button = {
        let button = Button(type: .system)
        button.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        button.tintColor = .textColor
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        titleLabel.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(refreshButton)

        refreshButton.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(4)
            make.centerY.equalToSuperview()
            make.width.equalTo(17)
        }

        refreshButton.addTarget(self, action: #selector(onTouchRefresh), for: .touchUpInside)
    }

    func configure(title: String, showRefreshButton: Bool) {
        titleLabel.text = title
        refreshButton.isHidden = !showRefreshButton
    }

    @objc private func onTouchRefresh() {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveLinear) {
            self.refreshButton.transform = CGAffineTransform(rotationAngle: .pi)
        } completion: { _ in
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveLinear) {
                self.refreshButton.transform = .identity
            } completion: { _ in
                self.onRefresh?()
            }
        }
    }
}

// MARK: - ServerHostListViewController

class ServerHostListViewController: ViewController {

    private let globalSettingModel: GlobalSettingModel

    init(globalSettingModel: GlobalSettingModel) {
        self.globalSettingModel = globalSettingModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerClassCell(class: TitleTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()

    private lazy var bag = DisposeBag()

    private var customHosts: [String]? {
        didSet {
            self.tableView.reloadSections(IndexSet(integer: Section.custom.rawValue), with: .automatic)
        }
    }

    private var backupHosts: [String]? {
        didSet {
            self.tableView.reloadSections(IndexSet(integer: Section.official.rawValue), with: .automatic)
        }
    }

    private var currentHost: String {
        return Preferences.shared.host
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("域名列表", comment: "")

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { make in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }

        let addItem = UIBarButtonItem(imageName: "Public/add", target: self, action: #selector(onTouchAddItem(_:)))
        self.navigationItem.rightBarButtonItem = addItem

        self.customHosts = Preferences.shared.customHosts

        // 先加载缓存，如果没有缓存则请求一次
        if let cachedBackupHosts = Preferences.shared.backupHosts {
            self.backupHosts = cachedBackupHosts
        } else {
            self.loadBackupHosts()
        }
    }

    private func loadBackupHosts() {
        _ = self.globalSettingModel.backupAddress().subscribe(onNext: { [weak self] hosts in
            guard let self = self else { return }
            self.backupHosts = hosts
            Preferences.shared.backupHosts = hosts
        }, onError: { [weak self] error in
            self?.view.showError(error)
        })
    }

    @objc private func onTouchAddItem(_ item: UIBarButtonItem) {
        let vc = UIAlertController(title: NSLocalizedString("添加自定义域名", comment: ""), message: nil, preferredStyle: .alert)

        weak var aTextField: UITextField?
        vc.addTextField { textField in
            textField.text = "http://"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            aTextField = textField
        }

        vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in

        }))

        vc.addAction(.init(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { [weak self] (_) in

            guard let text = aTextField?.text,
                  !text.isEmpty else {
                return
            }

            var hosts = self?.customHosts ?? []
            if !hosts.contains(text) {
                hosts.insert(text, at: 0)
                Preferences.shared.customHosts = hosts
                self?.customHosts = hosts
            }
        }))

        self.present(vc, atItem: item)
    }
}
