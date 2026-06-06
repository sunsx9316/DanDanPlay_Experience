//
//  DanmakuSettingViewController.swift
//  AniXPlayer
//
//  tvOS 弹幕设置 — 对齐 iOS DanmakuSettingViewController
//

import UIKit
import SnapKit
import RxSwift
import DanmakuRender

protocol DanmakuSettingViewControllerDelegate: AnyObject {
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController)
    func searchDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController)
    func filterDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController)
    func showDanmakuListInDanmakuSettingViewController(vc: DanmakuSettingViewController)
}

class DanmakuSettingViewController: ViewController {

    // MARK: - Properties

    private var dataSource: [DanmakuSettingInfo] {
        return self.danmakuModel.danmakuSetting
    }

    lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: SwitchSettingCell.self)
        tv.registerClassCell(class: StepperSettingCell.self)
        tv.registerClassCell(class: NavigationSettingCell.self)
        tv.registerClassCell(class: TitleMoreTableViewCell.self)
        tv.estimatedRowHeight = 76
        tv.rowHeight = UITableView.automaticDimension
        return tv
    }()

    private var danmakuModel: PlayerDanmakuModel {
        return self.playerModel.danmakuModel
    }

    private var playerModel: PlayerModel!

    weak var delegate: DanmakuSettingViewControllerDelegate?

    private lazy var disposeBag = DisposeBag()

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
    }
}

// MARK: - UITableViewDataSource

extension DanmakuSettingViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].dataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.dataSource[indexPath.section].dataSource[indexPath.row]

        switch type {
        case .danmakuInfo:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            let count = self.danmakuModel.danmakuList.count
            cell.configure(title: String(format: NSLocalizedString("弹幕信息(%d条)", comment: ""), count), detail: "")
            return cell

        case .danmakuAlpha:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let value = Double(danmakuModel.danmakuAlpha)
            cell.configure(title: type.title, value: value, min: 0, max: 1.0, step: 0.1,
                          formatter: { String(format: "%.0f%%", $0 * 100) })
            cell.onValueChanged = { [weak self] newValue in
                self?.danmakuModel.onChangeDanmakuAlpha(Float(newValue))
            }
            return cell

        case .danmakuFontSize:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let value = danmakuModel.danmakuFontSize
            cell.configure(title: type.title, value: value, min: 10, max: 40, step: 1)
            cell.onValueChanged = { [weak self] newValue in
                self?.danmakuModel.onChangeDanmakuFontSize(newValue)
            }
            return cell

        case .danmakuSpeed:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let value = danmakuModel.danmakuSpeed
            cell.configure(title: type.title, value: value, min: 0.5, max: 3.0, step: 0.1,
                          formatter: { String(format: "%.1fx", $0) })
            cell.onValueChanged = { [weak self] newValue in
                self?.danmakuModel.onChangeDanmakuSpeed(newValue)
            }
            return cell

        case .danmakuDensity:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let value = Double(danmakuModel.danmakuDensity)
            cell.configure(title: type.title, value: value, min: 1, max: 10, step: 1,
                          formatter: { String(format: "%.0f/10", $0) })
            cell.onValueChanged = { [weak self] newValue in
                self?.danmakuModel.onChangeDanmakuDensity(Float(newValue))
            }
            return cell

        case .danmakuArea:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, detail: danmakuModel.danmakuArea.title)
            return cell

        case .showDanmaku:
            let cell = tableView.dequeueCell(class: SwitchSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, isOn: danmakuModel.isShowDanmaku)
            cell.onSwitchChanged = { [weak self] isOn in
                self?.danmakuModel.onChangeIsShowDanmaku(isOn)
            }
            return cell

        case .danmakuOffsetTime:
            let cell = tableView.dequeueCell(class: StepperSettingCell.self, indexPath: indexPath)
            let value = Double(danmakuModel.danmakuOffsetTime)
            cell.configure(title: type.title, value: value, min: -500, max: 500, step: 1,
                          formatter: { [weak self] in self?.readableString(Int($0)) ?? "" })
            cell.onValueChanged = { [weak self] newValue in
                self?.danmakuModel.onChangeDanmakuOffsetTime(Int(newValue))
            }
            return cell

        case .loadDanmaku, .searchDanmaku, .filterDanmaku:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, detail: "")
            return cell

        case .mergeSameDanmaku:
            let cell = tableView.dequeueCell(class: SwitchSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, isOn: danmakuModel.isMergeSameDanmaku)
            cell.onSwitchChanged = { [weak self] isOn in
                self?.danmakuModel.onChangeIsMergeSameDanmaku(isOn)
            }
            return cell

        case .danmakuEffectStyle:
            let cell = tableView.dequeueCell(class: NavigationSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, detail: danmakuModel.danmakuEffectStyle.title)
            return cell

        case .openDanmakuRandomColor:
            let cell = tableView.dequeueCell(class: SwitchSettingCell.self, indexPath: indexPath)
            cell.configure(title: type.title, isOn: danmakuModel.openDanmakuRandomColor)
            cell.onSwitchChanged = { [weak self] isOn in
                self?.danmakuModel.onOpenDanmakuRandomColor(isOn)
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.dataSource[section].title
    }
}

// MARK: - UITableViewDelegate

extension DanmakuSettingViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let type = self.dataSource[indexPath.section].dataSource[indexPath.row]

        switch type {
        case .danmakuInfo:
            delegate?.showDanmakuListInDanmakuSettingViewController(vc: self)

        case .danmakuArea:
            showDanmakuAreaPicker()

        case .danmakuEffectStyle:
            showDanmakuEffectStylePicker()

        case .loadDanmaku:
            delegate?.loadDanmakuFileInDanmakuSettingViewController(vc: self)

        case .searchDanmaku:
            delegate?.searchDanmakuInDanmakuSettingViewController(vc: self)

        case .filterDanmaku:
            delegate?.filterDanmakuInDanmakuSettingViewController(vc: self)

        default:
            break
        }
    }

    // MARK: - Private

    private func showDanmakuAreaPicker() {
        let allCases = DanmakuAreaType.allCases
        let options = allCases.map { OptionListViewController.Option(title: $0.title) }
        let current = danmakuModel.danmakuArea
        let selectedIndex = allCases.firstIndex(of: current) ?? 0
        let vc = OptionListViewController(
            title: NSLocalizedString("显示区域", comment: ""),
            options: options,
            selectedIndex: selectedIndex
        )
        vc.onSelect = { [weak self] index in
            guard index < allCases.count else { return }
            let area = allCases[index]
            self?.danmakuModel.onChangeDanmakuArea(area)
            self?.tableView.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showDanmakuEffectStylePicker() {
        let allCases = DanmakuEffectStyle.allCases
        let options = allCases.map { OptionListViewController.Option(title: $0.title) }
        let current = danmakuModel.danmakuEffectStyle
        let selectedIndex = allCases.firstIndex(of: current) ?? 0
        let vc = OptionListViewController(
            title: NSLocalizedString("弹幕边缘样式", comment: ""),
            options: options,
            selectedIndex: selectedIndex
        )
        vc.onSelect = { [weak self] index in
            guard index < allCases.count else { return }
            let style = allCases[index]
            self?.danmakuModel.onChangeDanmaEffectStyle(style)
            self?.tableView.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
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