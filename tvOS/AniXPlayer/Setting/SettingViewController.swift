//
//  SettingViewController.swift
//  AniXPlayer
//
//  tvOS 设置 — 参考 iOS GlobalSettingType 结构
//

import UIKit
import SnapKit

class SettingViewController: ViewController {

    private enum Section: Int, CaseIterable {
        case general
        case danmaku
        case about

        var title: String {
            switch self {
            case .general: return NSLocalizedString("通用", comment: "")
            case .danmaku: return NSLocalizedString("弹幕", comment: "")
            case .about: return NSLocalizedString("关于", comment: "")
            }
        }
    }

    private enum SettingRow {
        case appLanguage
        case playerCore
        case autoLoadCustomSubtitle
        case mainColor
        case fastMatch
        case autoLoadDanmaku
        case danmakuCacheDay
        case version
        case cleanupCache
        case cleanupHistory

        var reuseIdentifier: String {
            switch self {
            case .fastMatch, .autoLoadDanmaku, .autoLoadCustomSubtitle:
                return SwitchSettingCell.reuseIdentifier
            case .appLanguage, .playerCore, .danmakuCacheDay, .mainColor,
                 .version, .cleanupCache, .cleanupHistory:
                return NavigationSettingCell.reuseIdentifier
            }
        }
    }

    private var model = GlobalSettingModel()

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(SwitchSettingCell.self, forCellReuseIdentifier: SwitchSettingCell.reuseIdentifier)
        tv.register(NavigationSettingCell.self, forCellReuseIdentifier: NavigationSettingCell.reuseIdentifier)
        tv.rowHeight = 66
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("设置", comment: "")

        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = tableView
    }

    private func rows(for section: Section) -> [SettingRow] {
        switch section {
        case .general:
            return [.appLanguage, .playerCore, .autoLoadCustomSubtitle, .mainColor]
        case .danmaku:
            return [.fastMatch, .autoLoadDanmaku, .danmakuCacheDay]
        case .about:
            return [.version, .cleanupCache, .cleanupHistory]
        }
    }

    private func configureCell(_ cell: UITableViewCell, for row: SettingRow) {
        switch row {
        case .appLanguage:
            if let cell = cell as? NavigationSettingCell {
                cell.configure(title: NSLocalizedString("语言", comment: ""),
                               detail: Preferences.shared.appLanguage.displayName)
            }

        case .playerCore:
            if let cell = cell as? NavigationSettingCell {
                cell.configure(title: NSLocalizedString("播放器内核", comment: ""), detail: "VLC")
                cell.showDisclosure = false
            }

        case .autoLoadCustomSubtitle:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("自动加载本地字幕", comment: ""),
                               isOn: Preferences.shared.autoLoadCustomSubtitle)
                cell.onSwitchChanged = { isOn in
                    Preferences.shared.autoLoadCustomSubtitle = isOn
                }
            }

        case .mainColor:
            if let cell = cell as? NavigationSettingCell {
                cell.configure(title: NSLocalizedString("主题色", comment: ""), detail: "")
                cell.colorIndicatorColor = Preferences.shared.mainColor
            }

        case .fastMatch:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("快速匹配弹幕", comment: ""),
                               isOn: Preferences.shared.fastMatch)
                cell.onSwitchChanged = { isOn in
                    Preferences.shared.fastMatch = isOn
                }
            }

        case .autoLoadDanmaku:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("自动加载本地弹幕", comment: ""),
                               isOn: Preferences.shared.autoLoadCustomDanmaku)
                cell.onSwitchChanged = { isOn in
                    Preferences.shared.autoLoadCustomDanmaku = isOn
                }
            }

        case .danmakuCacheDay:
            if let cell = cell as? NavigationSettingCell {
                let day = Preferences.shared.danmakuCacheDay
                let detail: String
                if day <= 0 {
                    detail = NSLocalizedString("不缓存", comment: "")
                } else {
                    detail = String(format: NSLocalizedString("%d天", comment: ""), day)
                }
                cell.configure(title: NSLocalizedString("弹幕缓存时间", comment: ""), detail: detail)
            }

        case .version:
            if let cell = cell as? NavigationSettingCell {
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                cell.configure(title: NSLocalizedString("版本", comment: ""), detail: version)
                cell.showDisclosure = false
            }

        case .cleanupCache:
            if let cell = cell as? NavigationSettingCell {
                cell.configure(title: NSLocalizedString("清除缓存", comment: ""), detail: "")
                cell.showDisclosure = false
            }

        case .cleanupHistory:
            if let cell = cell as? NavigationSettingCell {
                cell.configure(title: NSLocalizedString("清除播放记录", comment: ""), detail: "")
                cell.showDisclosure = false
            }
        }
    }

    // MARK: - Actions

    private func handleSelection(for row: SettingRow) {
        switch row {
        case .appLanguage:
            showAppLanguagePicker()
        case .mainColor:
            let colorVC = SetMainColorViewController()
            self.navigationController?.pushViewController(colorVC, animated: true)
        case .danmakuCacheDay:
            showDanmakuCacheDayInput()
        case .cleanupCache:
            showConfirm(
                title: NSLocalizedString("清除缓存", comment: ""),
                message: NSLocalizedString("确定清除缓存吗？", comment: "")
            ) { [weak self] in
                self?.model.cleanupCache()
                self?.showSuccess(NSLocalizedString("清除成功！", comment: ""))
            }
        case .cleanupHistory:
            showConfirm(
                title: NSLocalizedString("清除播放记录", comment: ""),
                message: NSLocalizedString("确定清除播放历史吗？", comment: "")
            ) { [weak self] in
                self?.model.cleanupHistory()
                self?.showSuccess(NSLocalizedString("清除成功！", comment: ""))
            }
        default:
            break
        }
    }

    private func showAppLanguagePicker() {
        let allCases = AppLanguage.allCases
        let options = allCases.map { OptionListViewController.Option(title: $0.displayName) }
        let current = Preferences.shared.appLanguage
        let selectedIndex = allCases.firstIndex(of: current) ?? 0
        let vc = OptionListViewController(
            title: NSLocalizedString("语言", comment: ""),
            options: options,
            selectedIndex: selectedIndex
        )
        vc.onSelect = { [weak self] index in
            guard index < allCases.count else { return }
            let language = allCases[index]
            self?.model.onChangeAppLanguage(language)
            self?.tableView.reloadData()

            // 提示重启
            let alert = UIAlertController(
                title: NSLocalizedString("提示", comment: ""),
                message: NSLocalizedString("语言切换已生效，退出后将以新语言启动", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("退出", comment: ""), style: .destructive) { _ in
                exit(0)
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
            self?.present(alert, animated: true)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showDanmakuCacheDayInput() {
        let alert = UIAlertController(
            title: NSLocalizedString("弹幕缓存时间", comment: ""),
            message: NSLocalizedString("0则不缓存", comment: ""),
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
            let day = max(0, Preferences.shared.danmakuCacheDay)
            textField.text = "\(day)"
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default) { [weak self] _ in
            guard let text = alert.textFields?.first?.text,
                  let day = Int(text) else { return }
            self?.model.onChangeDanmakuCacheDay(day)
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    private func showSuccess(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
        present(alert, animated: true)
    }

    private func showConfirm(title: String?, message: String?, action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .destructive) { _ in
            action()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SettingViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        return rows(for: sectionType).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        let row = rows(for: sectionType)[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: row.reuseIdentifier, for: indexPath)
        configureCell(cell, for: row)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = .white
            header.textLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        }
    }
}

// MARK: - UITableViewDelegate

extension SettingViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sectionType = Section(rawValue: indexPath.section) else { return }
        let row = rows(for: sectionType)[indexPath.row]
        handleSelection(for: row)
    }
}
