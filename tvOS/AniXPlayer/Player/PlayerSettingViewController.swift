//
//  PlayerSettingViewController.swift
//  AniXPlayer
//
//  tvOS 播放器设置 — TableView 分弹幕/播放/字幕/音频四大类
//

import UIKit
import SnapKit
import ANXLog
import DanmakuRender

class PlayerSettingViewController: ViewController {

    // MARK: - Section / Row

    private enum Section: Int, CaseIterable {
        case danmaku
        case playback
        case subtitle
        case audio

        var title: String {
            switch self {
            case .danmaku: return NSLocalizedString("弹幕设置", comment: "")
            case .playback: return NSLocalizedString("播放设置", comment: "")
            case .subtitle: return NSLocalizedString("字幕设置", comment: "")
            case .audio: return NSLocalizedString("音频设置", comment: "")
            }
        }
    }

    private enum Row {
        // Danmaku
        case showDanmaku
        case danmakuFontSize
        case danmakuSpeed
        case danmakuAlpha
        case danmakuDensity
        case danmakuEffectStyle
        case danmakuArea
        case openDanmakuRandomColor
        case mergeSameDanmaku
        case danmakuOffsetTime
        case searchDanmaku

        // Playback
        case playerSpeed
        case playerMode
        case aspectRatio
        case autoJumpTitleEnding
        case jumpTitleDuration
        case jumpEndingDuration

        // Subtitle
        case subtitleSafeArea
        case subtitleDelay
        case subtitleYPosition
        case subtitleFontSize
        case loadSubtitle

        // Audio
        case audioDelay

        var reuseIdentifier: String {
            switch self {
            case .showDanmaku, .openDanmakuRandomColor, .mergeSameDanmaku,
                 .autoJumpTitleEnding, .subtitleSafeArea:
                return SwitchSettingCell.reuseIdentifier
            case .danmakuFontSize, .danmakuSpeed, .danmakuAlpha, .danmakuDensity,
                 .danmakuOffsetTime, .playerSpeed, .jumpTitleDuration, .jumpEndingDuration,
                 .subtitleDelay, .subtitleYPosition, .subtitleFontSize, .audioDelay:
                return StepperSettingCell.reuseIdentifier
            case .danmakuEffectStyle, .danmakuArea, .playerMode, .aspectRatio,
                 .searchDanmaku, .loadSubtitle:
                return NavigationSettingCell.reuseIdentifier
            }
        }
    }

    // MARK: - Properties

    private let playerModel: PlayerModel
    private var mediaModel: PlayerMediaModel { playerModel.mediaModel }
    private var danmakuModel: PlayerDanmakuModel { playerModel.danmakuModel }
    private var blurView: UIVisualEffectView!

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(SwitchSettingCell.self, forCellReuseIdentifier: SwitchSettingCell.reuseIdentifier)
        tv.register(StepperSettingCell.self, forCellReuseIdentifier: StepperSettingCell.reuseIdentifier)
        tv.register(NavigationSettingCell.self, forCellReuseIdentifier: NavigationSettingCell.reuseIdentifier)
        tv.estimatedRowHeight = 76
        tv.rowHeight = UITableView.automaticDimension
        return tv
    }()

    // MARK: - Init

    init(playerModel: PlayerModel) {
        self.playerModel = playerModel
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("播放设置", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // 自适应模糊背景（浅色/深色模式自动切换）
        blurView = UIVisualEffectView(effect: adaptiveBlurEffect())
        view.insertSubview(blurView, at: 0)
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 透明 TableView 让模糊透出
        tableView.backgroundColor = .clear
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            blurView.effect = adaptiveBlurEffect()
        }
    }

    private func adaptiveBlurEffect() -> UIBlurEffect {
        return UIBlurEffect(style: traitCollection.userInterfaceStyle == .dark ? .dark : .light)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defaultFocusView = tableView
    }

    // MARK: - Row Config

    private func rows(for section: Section) -> [Row] {
        switch section {
        case .danmaku:
            return [
                .showDanmaku,
                .danmakuFontSize,
                .danmakuSpeed,
                .danmakuAlpha,
                .danmakuDensity,
                .danmakuEffectStyle,
                .danmakuArea,
                .openDanmakuRandomColor,
                .mergeSameDanmaku,
                .danmakuOffsetTime,
                .searchDanmaku,
            ]
        case .playback:
            var rows: [Row] = [
                .playerSpeed,
                .playerMode,
                .aspectRatio,
                .autoJumpTitleEnding,
            ]
            if Preferences.shared.autoJumpTitleEnding {
                rows.append(contentsOf: [.jumpTitleDuration, .jumpEndingDuration])
            }
            return rows
        case .subtitle:
            return [
                .subtitleSafeArea,
                .subtitleDelay,
                .subtitleYPosition,
                .subtitleFontSize,
                .loadSubtitle,
            ]
        case .audio:
            return [.audioDelay]
        }
    }

    private func configureCell(_ cell: UITableViewCell, for row: Row) {
        switch row {
        // MARK: Danmaku
        case .showDanmaku:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("弹幕开关", comment: ""), isOn: danmakuModel.isShowDanmaku)
                cell.onSwitchChanged = { [weak self] isOn in
                    self?.danmakuModel.onChangeIsShowDanmaku(isOn)
                }
            }
        case .danmakuFontSize:
            if let cell = cell as? StepperSettingCell {
                let value = Preferences.shared.danmakuFontSize
                cell.configure(title: NSLocalizedString("弹幕字体大小", comment: ""),
                               value: value, min: 20, max: 80, step: 1)
                cell.onValueChanged = { [weak self] newValue in
                    self?.danmakuModel.onChangeDanmakuFontSize(newValue)
                }
            }
        case .danmakuSpeed:
            if let cell = cell as? StepperSettingCell {
                let value = Preferences.shared.danmakuSpeed
                cell.configure(title: NSLocalizedString("弹幕速度", comment: ""),
                               value: value, min: 0.5, max: 3.0, step: 0.1,
                               formatter: { String(format: "%.1fx", $0) })
                cell.onValueChanged = { [weak self] newValue in
                    self?.danmakuModel.onChangeDanmakuSpeed(newValue)
                }
            }
        case .danmakuAlpha:
            if let cell = cell as? StepperSettingCell {
                let value = Preferences.shared.danmakuAlpha
                cell.configure(title: NSLocalizedString("弹幕透明度", comment: ""),
                               value: value, min: 0.1, max: 1.0, step: 0.1,
                               formatter: { String(format: "%.0f%%", $0 * 100) })
                cell.onValueChanged = { [weak self] newValue in
                    self?.danmakuModel.onChangeDanmakuAlpha(Float(newValue))
                }
            }
        case .danmakuDensity:
            if let cell = cell as? StepperSettingCell {
                let value = Double(Preferences.shared.danmakuDensity)
                cell.configure(title: NSLocalizedString("弹幕密度", comment: ""),
                               value: value, min: 1, max: 10, step: 1,
                               formatter: { String(format: "%.0f/10", $0) })
                cell.onValueChanged = { [weak self] newValue in
                    self?.danmakuModel.onChangeDanmakuDensity(Float(newValue))
                }
            }
        case .danmakuEffectStyle:
            if let cell = cell as? NavigationSettingCell {
                let style = Preferences.shared.danmakuEffectStyle
                cell.configure(title: NSLocalizedString("弹幕边缘样式", comment: ""), detail: style.title)
            }
        case .danmakuArea:
            if let cell = cell as? NavigationSettingCell {
                let area = Preferences.shared.danmakuArea
                cell.configure(title: NSLocalizedString("显示区域", comment: ""), detail: area.title)
            }
        case .openDanmakuRandomColor:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("随机弹幕颜色", comment: ""), isOn: Preferences.shared.openDanmakuRandomColor)
                cell.onSwitchChanged = { [weak self] isOn in
                    self?.danmakuModel.onOpenDanmakuRandomColor(isOn)
                }
            }
        case .mergeSameDanmaku:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("合并重复弹幕", comment: ""), isOn: Preferences.shared.isMergeSameDanmaku)
                cell.onSwitchChanged = { [weak self] isOn in
                    self?.danmakuModel.onChangeIsMergeSameDanmaku(isOn)
                }
            }
        case .danmakuOffsetTime:
            if let cell = cell as? StepperSettingCell {
                let value = Double(Preferences.shared.danmakuOffsetTime)
                cell.configure(title: NSLocalizedString("弹幕偏移时间", comment: ""),
                               value: value, min: -500, max: 500, step: 1,
                               formatter: { String(format: "%.0fs", $0) })
                cell.onValueChanged = { [weak self] newValue in
                    self?.danmakuModel.onChangeDanmakuOffsetTime(Int(newValue))
                }
            }
        case .searchDanmaku:
            if let cell = cell as? NavigationSettingCell {
                cell.configure(title: NSLocalizedString("搜索弹幕", comment: ""), detail: "")
            }

        // MARK: Playback
        case .playerSpeed:
            if let cell = cell as? StepperSettingCell {
                let value = mediaModel.playerSpeed
                cell.configure(title: NSLocalizedString("播放速度", comment: ""),
                               value: value, min: 0.5, max: 3.0, step: 0.25,
                               formatter: { String(format: "%.2fx", $0) })
                cell.onValueChanged = { [weak self] newValue in
                    self?.mediaModel.onChangePlayerSpeed(newValue)
                }
            }
        case .playerMode:
            if let cell = cell as? NavigationSettingCell {
                let mode = mediaModel.playerMode
                cell.configure(title: NSLocalizedString("播放模式", comment: ""), detail: mode.title)
            }
        case .aspectRatio:
            if let cell = cell as? NavigationSettingCell {
                let ratio = mediaModel.aspectRatio
                cell.configure(title: NSLocalizedString("宽高比", comment: ""), detail: ratio.name)
            }
        case .autoJumpTitleEnding:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("自动跳过片头片尾", comment: ""), isOn: Preferences.shared.autoJumpTitleEnding)
                cell.onSwitchChanged = { [weak self] isOn in
                    self?.mediaModel.onChangeAutoJumpTitleEnding(isOn)
                    self?.tableView.reloadData()
                }
            }
        case .jumpTitleDuration:
            if let cell = cell as? StepperSettingCell {
                let value = Double(Preferences.shared.jumpTitleDuration)
                cell.configure(title: NSLocalizedString("跳过片头时长", comment: ""),
                               value: value, min: 0, max: 600, step: 1,
                               formatter: { String(format: "%.0fs", $0) })
                cell.onValueChanged = { newValue in
                    Preferences.shared.jumpTitleDuration = newValue
                }
            }
        case .jumpEndingDuration:
            if let cell = cell as? StepperSettingCell {
                let value = Double(Preferences.shared.jumpEndingDuration)
                cell.configure(title: NSLocalizedString("跳过片尾时长", comment: ""),
                               value: value, min: 0, max: 600, step: 1,
                               formatter: { String(format: "%.0fs", $0) })
                cell.onValueChanged = { newValue in
                    Preferences.shared.jumpEndingDuration = newValue
                }
            }

        // MARK: Subtitle
        case .subtitleSafeArea:
            if let cell = cell as? SwitchSettingCell {
                cell.configure(title: NSLocalizedString("防挡字幕", comment: ""), isOn: Preferences.shared.subtitleSafeArea)
                cell.onSwitchChanged = { [weak self] isOn in
                    self?.mediaModel.onChangeSubtitleSafeArea(isOn)
                }
            }
        case .subtitleDelay:
            if let cell = cell as? StepperSettingCell {
                let value = Double(mediaModel.subtitleOffsetTime)
                cell.configure(title: NSLocalizedString("字幕时间偏移", comment: ""),
                               value: value, min: -500, max: 500, step: 1,
                               formatter: { String(format: "%.0fs", $0) })
                cell.onValueChanged = { [weak self] newValue in
                    self?.mediaModel.onChangeSubtitleOffsetTime(Int(newValue))
                }
            }
        case .subtitleYPosition:
            if let cell = cell as? StepperSettingCell {
                let value = Double(mediaModel.subtitleYPosition)
                cell.configure(title: NSLocalizedString("字幕Y轴偏移", comment: ""),
                               value: value, min: 0, max: 100, step: 1,
                               formatter: { String(format: "%.0f%%", $0) })
                cell.onValueChanged = { [weak self] newValue in
                    self?.mediaModel.onChangeSubtitleYPosition(Float(newValue))
                }
            }
        case .subtitleFontSize:
            if let cell = cell as? StepperSettingCell {
                let value = Double(mediaModel.subtitleFontSize)
                cell.configure(title: NSLocalizedString("字幕大小", comment: ""),
                               value: value, min: 10, max: 120, step: 1)
                cell.onValueChanged = { [weak self] newValue in
                    self?.mediaModel.onChangeSubtitleFontSize(Float(newValue))
                }
            }
        case .loadSubtitle:
            if let cell = cell as? NavigationSettingCell {
                cell.configure(title: NSLocalizedString("加载字幕...", comment: ""), detail: "")
            }

        // MARK: Audio
        case .audioDelay:
            if let cell = cell as? StepperSettingCell {
                let value = Double(mediaModel.audioOffsetTime)
                cell.configure(title: NSLocalizedString("音频时间偏移", comment: ""),
                               value: value, min: -100, max: 100, step: 1,
                               formatter: { String(format: "%.0fs", $0) })
                cell.onValueChanged = { [weak self] newValue in
                    self?.mediaModel.onChangeAudioOffsetTime(Int(newValue))
                }
            }
        }
    }

    private func handleSelection(for row: Row) {
        switch row {
        case .danmakuEffectStyle:
            let allCases = DanmakuEffectStyle.allCases
            let options = allCases.map { OptionListViewController.Option(title: $0.title) }
            let current = Preferences.shared.danmakuEffectStyle
            let selectedIndex = allCases.firstIndex(of: current) ?? 0
            let vc = OptionListViewController(
                title: NSLocalizedString("弹幕边缘样式", comment: ""),
                options: options,
                selectedIndex: selectedIndex
            )
            vc.onSelect = { [weak self] index in
                guard index < allCases.count else { return }
                let style = allCases[index]
                Preferences.shared.danmakuEffectStyle = style
                self?.danmakuModel.onChangeDanmaEffectStyle(style)
                self?.tableView.reloadData()
            }
            navigationController?.pushViewController(vc, animated: true)

        case .danmakuArea:
            let allCases = DanmakuAreaType.allCases
            let options = allCases.map { OptionListViewController.Option(title: $0.title) }
            let current = Preferences.shared.danmakuArea
            let selectedIndex = allCases.firstIndex(of: current) ?? 0
            let vc = OptionListViewController(
                title: NSLocalizedString("显示区域", comment: ""),
                options: options,
                selectedIndex: selectedIndex
            )
            vc.onSelect = { [weak self] index in
                guard index < allCases.count else { return }
                let area = allCases[index]
                Preferences.shared.danmakuArea = area
                self?.danmakuModel.onChangeDanmakuArea(area)
                self?.tableView.reloadData()
            }
            navigationController?.pushViewController(vc, animated: true)

        case .playerMode:
            let allCases = PlayerMode.allCases
            let options = allCases.map { OptionListViewController.Option(title: $0.title) }
            let current = mediaModel.playerMode
            let selectedIndex = allCases.firstIndex(of: current) ?? 0
            let vc = OptionListViewController(
                title: NSLocalizedString("播放模式", comment: ""),
                options: options,
                selectedIndex: selectedIndex
            )
            vc.onSelect = { [weak self] index in
                guard index < allCases.count else { return }
                let mode = allCases[index]
                self?.mediaModel.onChangePlayerMode(mode)
                self?.tableView.reloadData()
            }
            navigationController?.pushViewController(vc, animated: true)

        case .aspectRatio:
            let ratioList = mediaModel.aspectRatioList
            let options = ratioList.map { OptionListViewController.Option(title: $0.name) }
            let current = mediaModel.aspectRatio
            let selectedIndex = ratioList.firstIndex(where: { $0.rawValue == current.rawValue }) ?? 0
            let vc = OptionListViewController(
                title: NSLocalizedString("宽高比", comment: ""),
                options: options,
                selectedIndex: selectedIndex
            )
            vc.onSelect = { [weak self] index in
                guard index < ratioList.count else { return }
                let ratio = ratioList[index]
                self?.mediaModel.onChangeAspectRatio(ratio)
                self?.tableView.reloadData()
            }
            navigationController?.pushViewController(vc, animated: true)

        case .searchDanmaku:
            guard let media = mediaModel.media else { return }
            ANX.logInfo(.player, "[PlayerSetting] 打开弹幕搜索")
            let matchVC = MatchsViewController(file: media, playerModel: playerModel)
            navigationController?.pushViewController(matchVC, animated: true)

        case .loadSubtitle:
            ANX.logInfo(.player, "[PlayerSetting] 打开字幕加载")
            let fileBrowserVC = FileBrowserViewController(directory: LocalFile.rootFile)
            fileBrowserVC.filterType = .subtitle
            fileBrowserVC.didSelectFile = { [weak self] file in
                self?.navigationController?.popViewController(animated: false)
                _ = self?.mediaModel.loadSubtitleByUser(file).subscribe()
            }
            navigationController?.pushViewController(fileBrowserVC, animated: true)

        default:
            break
        }
    }
}

// MARK: - UITableViewDataSource

extension PlayerSettingViewController: UITableViewDataSource {
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
}

// MARK: - UITableViewDelegate

extension PlayerSettingViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sectionType = Section(rawValue: indexPath.section) else { return }
        let row = rows(for: sectionType)[indexPath.row]
        handleSelection(for: row)
    }
}
