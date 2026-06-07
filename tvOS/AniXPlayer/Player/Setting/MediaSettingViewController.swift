//
//  MediaSettingViewController.swift
//  AniXPlayer
//
//  tvOS 媒体设置 — 对齐 iOS MediaSettingViewController
//

import UIKit
import SnapKit
import RxSwift

protocol MediaSettingViewControllerDelegate: AnyObject {
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController)
    func changeSubtitleFontInMediaSettingViewController(_ vc: MediaSettingViewController)
}

class MediaSettingViewController: ViewController {

    // MARK: - Properties

    private lazy var dataSource = [MediaSettingInfo]()

    lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: SwitchSettingCell.self)
        tv.registerClassCell(class: StepperSettingCell.self)
        tv.registerClassCell(class: NavigationSettingCell.self)
        tv.registerClassCell(class: TitleTableViewCell.self)
        tv.register(SectionHeaderView.self, forHeaderFooterViewReuseIdentifier: SectionHeaderView.reuseIdentifier)
        tv.estimatedRowHeight = 76
        tv.rowHeight = UITableView.automaticDimension
        return tv
    }()

    private var mediaModel: PlayerMediaModel {
        return self.playerModel.mediaModel
    }

    private var playerModel: PlayerModel!

    weak var delegate: MediaSettingViewControllerDelegate?

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm:ss"
        return formatter
    }()

    // MARK: - Init

    init(playerModel: PlayerModel) {
        self.playerModel = playerModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.leading.equalToSuperview().offset(40)
        }

        reloadData()
    }

    private func reloadData() {
        self.dataSource = self.mediaModel.mediaSetting
        self.tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension MediaSettingViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].dataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.dataSource[indexPath.section].dataSource[indexPath.row]

        switch type {
        case .subtitleSafeArea:
            let cell = tableView.dequeueCell(class: SwitchSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, isOn: mediaModel.subtitleSafeArea)
            cell.onSwitchChanged = { [weak self] isOn in
                self?.mediaModel.onChangeSubtitleSafeArea(isOn)
            }
            return cell

        case .miniProgressBar:
            let cell = tableView.dequeueCell(class: SwitchSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, isOn: Preferences.shared.miniProgressBar)
            cell.onSwitchChanged = { [weak self] isOn in
                self?.mediaModel.onChangeMiniProgressBar(isOn)
            }
            return cell

        case .playerSpeed:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let range = mediaModel.playerSpeedRange()
            let value = mediaModel.playerSpeed
            cell.configure(title: type.title, value: value, min: Double(range.min), max: Double(range.max), step: Double(range.step),
                          formatter: { String(format: "%.2fx", $0) })
            cell.onValueChanged = { [weak self] newValue in
                self?.mediaModel.onChangePlayerSpeed(newValue)
            }
            return cell

        case .playerMode:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, detail: mediaModel.playerMode.title)
            return cell

        case .aspectRatio:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, detail: mediaModel.aspectRatio.name)
            return cell

        case .loadSubtitle:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, detail: "")
            return cell

        case .subtitleTrack:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, detail: mediaModel.currentSubtitle?.subtitleName ?? NSLocalizedString("无", comment: ""))
            return cell

        case .audioTrack:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, detail: mediaModel.currentAudioChannel?.audioName ?? NSLocalizedString("无", comment: ""))
            return cell

        case .autoJumpTitleEnding:
            let cell = tableView.dequeueCell(class: SwitchSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, isOn: mediaModel.autoJumpTitleEnding)
            cell.onSwitchChanged = { [weak self] isOn in
                self?.mediaModel.onChangeAutoJumpTitleEnding(isOn)
                self?.reloadData()
            }
            return cell

        case .jumpTitleDuration:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let range = mediaModel.jumpTitleDurationRange()
            let value = mediaModel.jumpTitleDuration
            cell.configure(title: type.title, value: Double(value), min: Double(range.min), max: Double(range.max), step: Double(range.step),
                          formatter: { [weak self] in self?.formatTime($0) ?? "" })
            cell.onValueChanged = { [weak self] newValue in
                self?.mediaModel.onChangeJumpTitleDuration(newValue)
            }
            return cell

        case .jumpEndingDuration:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let range = mediaModel.jumpTitleDurationRange()
            let value = mediaModel.jumpEndingDuration
            cell.configure(title: type.title, value: Double(value), min: Double(range.min), max: Double(range.max), step: Double(range.step),
                          formatter: { [weak self] in self?.formatTime($0) ?? "" })
            cell.onValueChanged = { [weak self] newValue in
                self?.mediaModel.onChangeJumpEndingDuration(newValue)
            }
            return cell

        case .subtitleDelay:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let range = mediaModel.subtitleDelayRange()
            let value = Double(mediaModel.subtitleOffsetTime)
            cell.configure(title: type.title, value: value, min: range.min, max: range.max, step: 1,
                          formatter: { [weak self] in self?.readableString(Int($0)) ?? "" })
            cell.onValueChanged = { [weak self] newValue in
                self?.mediaModel.onChangeSubtitleOffsetTime(Int(newValue))
            }
            return cell

        case .subtitleYPosition:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let range = mediaModel.subtitleYPositionRange()
            let value = Double(mediaModel.subtitleYPosition)
            cell.configure(title: type.title, value: value, min: Double(range.min), max: Double(range.max), step: 1,
                          formatter: { String(format: "%.0f%%", $0) })
            cell.onValueChanged = { [weak self] newValue in
                self?.mediaModel.onChangeSubtitleYPosition(Float(newValue))
            }
            return cell

        case .subtitleFontSize:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let range = mediaModel.subtitleFontSizeRange()
            let value = Double(mediaModel.subtitleFontSize)
            cell.configure(title: type.title, value: value, min: Double(range.min), max: Double(range.max), step: Double(range.step))
            cell.onValueChanged = { [weak self] newValue in
                self?.mediaModel.onChangeSubtitleFontSize(Float(newValue))
            }
            return cell

        case .matchInfo:
            let cell = tableView.dequeueCell(class: TitleTableViewCell.self, indexPath: indexPath)
            if let media = self.mediaModel.media {
                let matchInfo = self.mediaModel.matchInfo(media: media)
                cell.label.text = matchInfo?.matchDesc ?? NSLocalizedString("无", comment: "")
            } else {
                cell.label.text = NSLocalizedString("无", comment: "")
            }
            return cell

        case .audioDelay:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let range = mediaModel.audioDelayRange()
            let value = Double(mediaModel.audioOffsetTime)
            cell.configure(title: type.title, value: value, min: range.min, max: range.max, step: 1,
                          formatter: { [weak self] in self?.readableString(Int($0)) ?? "" })
            cell.onValueChanged = { [weak self] newValue in
                self?.mediaModel.onChangeAudioOffsetTime(Int(newValue))
            }
            return cell

        case .subtitleFont:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, detail: mediaModel.subtitleFontReadableName())
            return cell

        case .subtitleColor:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            let color = mediaModel.subtitleColor ?? .white
            cell.colorIndicatorColor = color
            let colorName = Self.subtitleColorName(mediaModel.subtitleColor)
            cell.configure(title: type.title, detail: colorName)
            return cell

        case .subtitleStyle:
            let cell = tableView.dequeueCell(class: SwitchSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, isOn: Preferences.shared.subtitleStyle)
            cell.onSwitchChanged = { [weak self] isOn in
                self?.mediaModel.onChangeSubtitleStyle(isOn)
                self?.reloadData()
            }
            return cell

        default:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: SectionHeaderView.reuseIdentifier) as? SectionHeaderView
        header?.title = self.dataSource[section].title
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 55
    }
}

// MARK: - UITableViewDelegate

extension MediaSettingViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let type = self.dataSource[indexPath.section].dataSource[indexPath.row]

        switch type {
        case .playerMode:
            showPlayerModePicker()

        case .loadSubtitle:
            delegate?.loadSubtitleFileInMediaSettingViewController(self)

        case .subtitleTrack:
            showSubtitleTrackPicker()

        case .audioTrack:
            showAudioTrackPicker()

        case .aspectRatio:
            showAspectRatioPicker()

        case .subtitleColor:
            showSubtitleColorPicker()

        case .subtitleFont:
            delegate?.changeSubtitleFontInMediaSettingViewController(self)

        default:
            break
        }
    }
}

// MARK: - Private

extension MediaSettingViewController {

    private func showPlayerModePicker() {
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
            self?.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showSubtitleTrackPicker() {
        guard mediaModel.media != nil else { return }
        let localSubtitleList = mediaModel.subtitleList
        guard !localSubtitleList.isEmpty else { return }

        let options = localSubtitleList.map { OptionListViewController.Option(title: $0.subtitleName) }
        let vc = OptionListViewController(
            title: NSLocalizedString("字幕轨道", comment: ""),
            options: options,
            selectedIndex: 0
        )
        vc.onSelect = { [weak self] index in
            guard index < localSubtitleList.count else { return }
            self?.mediaModel.currentSubtitle = localSubtitleList[index]
            self?.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showAudioTrackPicker() {
        let audioChannelList = mediaModel.audioChannelList
        guard !audioChannelList.isEmpty else { return }

        let options = audioChannelList.map { OptionListViewController.Option(title: $0.audioName) }
        let vc = OptionListViewController(
            title: NSLocalizedString("音轨", comment: ""),
            options: options,
            selectedIndex: 0
        )
        vc.onSelect = { [weak self] index in
            guard index < audioChannelList.count else { return }
            self?.mediaModel.currentAudioChannel = audioChannelList[index]
            self?.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showAspectRatioPicker() {
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
            self?.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private static let subtitleColorPresetColors: [ANXColor] = [
        .white, .yellow, .green, .cyan, .blue, .magenta, .red, .orange,
    ]

    static func subtitleColorName(_ color: ANXColor?) -> String {
        guard color != nil else { return NSLocalizedString("默认", comment: "") }
        return NSLocalizedString("自定义", comment: "")
    }

    private func showSubtitleColorPicker() {
        let vc = SubtitleColorPickerViewController()
        vc.title = NSLocalizedString("字幕颜色", comment: "")
        vc.colors = Self.subtitleColorPresetColors
        vc.selectedColor = mediaModel.subtitleColor
        vc.allowsNilSelection = true
        vc.onSelect = { [weak self] color in
            self?.mediaModel.onChangeSubtitleColor(color)
            self?.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func formatTime(_ seconds: Double) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        return dateFormatter.string(from: date)
    }

    private func readableString(_ offsetTime: Int) -> String {
        if offsetTime < 0 {
            return String(format: NSLocalizedString("延后(%ds)", comment: ""), abs(offsetTime))
        } else if offsetTime > 0 {
            return String(format: NSLocalizedString("提前(%ds)", comment: ""), abs(offsetTime))
        }
        return NSLocalizedString("无偏移", comment: "")
    }
}
