//
//  FilterDanmakuViewController.swift
//  AniXPlayer
//
//  tvOS 弹幕过滤列表 — 对齐 iOS FilterDanmakuViewController
//

import UIKit
import SnapKit
import RxSwift

class FilterDanmakuViewController: ViewController {

    // MARK: - Data

    private var dataSource: [FilterDanmaku] {
        return self.danmakuModel.filterDanmakus ?? []
    }

    private let danmakuModel: PlayerDanmakuModel!

    private lazy var bag = DisposeBag()

    // MARK: - UI

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(NavigationSettingCell.self, forCellReuseIdentifier: NavigationSettingCell.reuseIdentifier)
        tv.register(TableViewCell.self, forCellReuseIdentifier: "AddCell")
        tv.rowHeight = 76
        return tv
    }()

    // MARK: - Init

    init(danmakuModel: PlayerDanmakuModel) {
        self.danmakuModel = danmakuModel
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("弹幕过滤列表", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(40)
        }

        self.danmakuModel.context.filterDanmakus.subscribe(onNext: { [weak self] _ in
            self?.tableView.reloadData()
        }).disposed(by: self.bag)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defaultFocusView = tableView
    }

    // MARK: - Actions

    private func showAddFilterAlert() {
        let alert = UIAlertController(
            title: NSLocalizedString("添加屏蔽弹幕", comment: ""),
            message: NSLocalizedString("支持正则表达式", comment: ""),
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = NSLocalizedString("输入屏蔽关键词或正则", comment: "")
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            self?.danmakuModel.onAddFilterDanmku(text)
        })

        present(alert, animated: true)
    }

    private func showFilterOptions(for filter: FilterDanmaku, at index: Int) {
        let alert = UIAlertController(
            title: filter.text,
            message: nil,
            preferredStyle: .actionSheet
        )

        let enableTitle = filter.isEnable
            ? NSLocalizedString("禁用", comment: "")
            : NSLocalizedString("启用", comment: "")
        alert.addAction(UIAlertAction(title: enableTitle, style: .default) { [weak self] _ in
            var newDataSource = self?.dataSource
            newDataSource?[index].isEnable.toggle()
            self?.danmakuModel.onChangeFilterDanmkus(newDataSource)
        })

        let regexTitle = filter.isRegularExp
            ? NSLocalizedString("切换为普通文本", comment: "")
            : NSLocalizedString("切换为正则表达式", comment: "")
        alert.addAction(UIAlertAction(title: regexTitle, style: .default) { [weak self] _ in
            var newDataSource = self?.dataSource
            newDataSource?[index].isRegularExp.toggle()
            self?.danmakuModel.onChangeFilterDanmkus(newDataSource)
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("删除", comment: ""), style: .destructive) { [weak self] _ in
            self?.danmakuModel.onRemoveFilterDanmkus(filter)
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))

        present(alert, animated: true)
    }

    private func statusText(for filter: FilterDanmaku) -> String {
        let enableText = filter.isEnable
            ? NSLocalizedString("启用", comment: "")
            : NSLocalizedString("禁用", comment: "")
        let typeText = filter.isRegularExp
            ? NSLocalizedString("正则", comment: "")
            : NSLocalizedString("普通", comment: "")
        return "\(enableText) · \(typeText)"
    }
}

// MARK: - UITableViewDataSource

extension FilterDanmakuViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : dataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AddCell", for: indexPath)
            cell.textLabel?.text = NSLocalizedString("添加屏蔽弹幕", comment: "")
            cell.textLabel?.font = .ddp_small(weight: .medium)
            cell.textLabel?.textColor = .systemBlue
            cell.accessoryType = .none
            cell.selectionStyle = .none
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: NavigationSettingCell.reuseIdentifier, for: indexPath) as! NavigationSettingCell
            let filter = dataSource[indexPath.row]
            cell.configure(title: filter.text ?? "", detail: statusText(for: filter))
            cell.showDisclosure = true
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension FilterDanmakuViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            showAddFilterAlert()
        } else {
            let filter = dataSource[indexPath.row]
            showFilterOptions(for: filter, at: indexPath.row)
        }
    }
}
