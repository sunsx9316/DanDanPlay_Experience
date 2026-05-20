//
//  SettingViewController.swift
//  AniXPlayer
//
//  tvOS 设置 — TableView 设置列表 + 焦点导航
//

import UIKit
import SnapKit

class SettingViewController: ViewController {

    private enum Section: Int, CaseIterable {
        case player
        case danmaku
        case display
        case about

        var title: String {
            switch self {
            case .player: return NSLocalizedString("播放", comment: "")
            case .danmaku: return NSLocalizedString("弹幕", comment: "")
            case .display: return NSLocalizedString("显示", comment: "")
            case .about: return NSLocalizedString("关于", comment: "")
            }
        }
    }

    private enum SettingRow {
        case playerCore
        case fastMatch
        case autoLoadDanmaku
        case danmakuFontSize
        case danmakuSpeed
        case danmakuDensity
        case danmakuAlpha
        case subtitleSafeArea
        case mainColor
        case version

        var reuseIdentifier: String {
            switch self {
            case .fastMatch, .autoLoadDanmaku, .subtitleSafeArea:
                return SwitchSettingCell.reuseIdentifier
            case .playerCore, .mainColor:
                return NavigationSettingCell.reuseIdentifier
            case .danmakuFontSize, .danmakuSpeed, .danmakuDensity, .danmakuAlpha:
                return NavigationSettingCell.reuseIdentifier
            case .version:
                return "DefaultCell"
            }
        }
    }

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(SwitchSettingCell.self, forCellReuseIdentifier: SwitchSettingCell.reuseIdentifier)
        tv.register(NavigationSettingCell.self, forCellReuseIdentifier: NavigationSettingCell.reuseIdentifier)
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = tableView
    }

    private func rows(for section: Section) -> [SettingRow] {
        switch section {
        case .player:
            return [.playerCore]
        case .danmaku:
            return [.fastMatch, .autoLoadDanmaku, .danmakuFontSize, .danmakuSpeed, .danmakuDensity, .danmakuAlpha]
        case .display:
            return [.subtitleSafeArea, .mainColor]
        case .about:
            return [.version]
        }
    }

    private func configureCell(_ cell: UITableViewCell, for row: SettingRow) {
        switch row {
        case .playerCore:
            if let cell = cell as? NavigationSettingCell {
                cell.configure(title: NSLocalizedString("播放器内核", comment: ""), detail: "VLC")
            }

        case .fastMatch:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("快速匹配弹幕", comment: ""), isOn: Preferences.shared.fastMatch)
                cell.onSwitchChanged = { isOn in
                    Preferences.shared.fastMatch = isOn
                }
            }

        case .autoLoadDanmaku:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("自动加载弹幕", comment: ""), isOn: Preferences.shared.autoLoadCustomDanmaku)
                cell.onSwitchChanged = { isOn in
                    Preferences.shared.autoLoadCustomDanmaku = isOn
                }
            }

        case .danmakuFontSize:
            if let cell = cell as? NavigationSettingCell {
                let size = Int(Preferences.shared.danmakuFontSize)
                cell.configure(title: NSLocalizedString("弹幕字体大小", comment: ""), detail: "\(size)")
            }

        case .danmakuSpeed:
            if let cell = cell as? NavigationSettingCell {
                let speed = Int(Preferences.shared.danmakuSpeed)
                cell.configure(title: NSLocalizedString("弹幕速度", comment: ""), detail: "\(speed)")
            }

        case .danmakuDensity:
            if let cell = cell as? NavigationSettingCell {
                let density = Int(Preferences.shared.danmakuDensity)
                cell.configure(title: NSLocalizedString("弹幕密度", comment: ""), detail: "\(density)")
            }

        case .danmakuAlpha:
            if let cell = cell as? NavigationSettingCell {
                let alpha = Int(Preferences.shared.danmakuAlpha * 100)
                cell.configure(title: NSLocalizedString("弹幕透明度", comment: ""), detail: "\(alpha)%")
            }

        case .subtitleSafeArea:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("字幕安全区域", comment: ""), isOn: Preferences.shared.subtitleSafeArea)
                cell.onSwitchChanged = { isOn in
                    Preferences.shared.subtitleSafeArea = isOn
                }
            }

        case .mainColor:
            if let cell = cell as? NavigationSettingCell {
                cell.configure(title: NSLocalizedString("主题色", comment: ""), detail: "")
                cell.colorIndicatorColor = ANXColor.defaultMainColor
            }

        case .version:
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            cell.textLabel?.text = NSLocalizedString("版本", comment: "")
            cell.detailTextLabel?.text = version
            cell.textLabel?.textColor = .lightGray
            cell.detailTextLabel?.textColor = .lightGray
            cell.backgroundColor = .clear
        }
    }

    private func handleSelection(for row: SettingRow) {
        switch row {
        case .playerCore:
            break // Only VLC on tvOS
        case .mainColor:
            let colorVC = SetMainColorViewController()
            self.navigationController?.pushViewController(colorVC, animated: true)
        default:
            break
        }
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
