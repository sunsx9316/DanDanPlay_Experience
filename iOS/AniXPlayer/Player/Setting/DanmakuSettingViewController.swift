//
//  DanmakuSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/20.
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
    
    private var dataSource: [DanmakuSettingInfo] {
        return self.danmakuModel.danmakuSetting
    }
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerClassCell(class: SliderTableViewCell.self)
        tableView.registerNibCell(class: SwitchTableViewCell.self)
        tableView.registerNibCell(class: StepTableViewCell.self)
        tableView.registerClassCell(class: TitleTableViewCell.self)
        tableView.registerNibCell(class: SheetTableViewCell.self)
        tableView.registerNibCell(class: TitleMoreTableViewCell.self)
        tableView.registerClassHeaderFooterView(class: TitleTableViewHeaderFooterView.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .clear
        
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = .darkGray
        return tableView
    }()

    private var danmakuModel: PlayerDanmakuModel {
        return self.playerModel.danmakuModel
    }
    
    private var playerModel: PlayerModel!
    
    private lazy var disposeBag = DisposeBag()
    
    weak var delegate: DanmakuSettingViewControllerDelegate?
    
    init(playerModel: PlayerModel) {
        self.playerModel = playerModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .clear
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        self.tableView.reloadData()
    }


}

extension DanmakuSettingViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueHeaderFooterView(class: TitleTableViewHeaderFooterView.self)
        view.titleLabel.text = self.dataSource[section].title
        view.titleLabel.textColor = .mainColor
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].dataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.dataSource[indexPath.section].dataSource[indexPath.row]
        
        switch type {
        case .danmakuInfo:
            let cell = tableView.dequeueCell(class: TitleMoreTableViewCell.self, indexPath: indexPath)
            let count = self.danmakuModel.danmakuList.count
            cell.label.text = String(format: NSLocalizedString("弹幕信息(%d条)", comment: ""), count)
            return cell
        case .danmakuAlpha:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.valueSlider.isContinuous = true
            cell.selectionStyle = .none
            cell.step = 0.1
            let model = SliderTableViewCell.Model(maxValue: 1,
                                                  minValue: 0,
                                                  currentValue: self.danmakuModel.danmakuAlpha)
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.value
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.danmakuModel.onChangeDanmakuAlpha(currentValue)
            }
            return cell
        case .danmakuFontSize:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.titleLabel.text = type.title
            cell.step = 1
            let model = SliderTableViewCell.Model(maxValue: 40,
                                                  minValue: 10,
                                                  currentValue: Float(self.danmakuModel.danmakuFontSize))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = Int(aCell.valueSlider.value)
                let model = aCell.model
                model?.currentValue = Float(currentValue)
                aCell.model = model
                
                self.danmakuModel.onChangeDanmakuFontSize(Double(currentValue))
            }
            return cell
        case .danmakuSpeed:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.titleLabel.text = type.title
            cell.valueSlider.isContinuous = true
            cell.step = 0.1
            let model = SliderTableViewCell.Model(maxValue: 3,
                                                  minValue: 0.5,
                                                  currentValue: Float(self.danmakuModel.danmakuSpeed))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.value
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.danmakuModel.onChangeDanmakuSpeed(Double(currentValue))
            }
            return cell
        case .danmakuArea:
            let cell = tableView.dequeueCell(class: SheetTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.valueLabel.text = self.danmakuModel.danmakuArea.title
            return cell
        case .showDanmaku:
            let cell = tableView.dequeueCell(class: SwitchTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.aSwitch.isOn = self.danmakuModel.isShowDanmaku
            cell.titleLabel.text = type.title
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                self.danmakuModel.onChangeIsShowDanmaku(isOn)
            }
            return cell
        case .danmakuOffsetTime:
            let cell = tableView.dequeueCell(class: StepTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.titleLabel.text = type.title
            let danmakuOffsetTime = self.danmakuModel.danmakuOffsetTime
            cell.stepper.minimumValue = -500
            cell.stepper.maximumValue = 500
            cell.stepper.value = Double(danmakuOffsetTime)
            cell.valueLabel.text = readableString(danmakuOffsetTime)
            cell.onTouchStepperCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let value = Int(aCell.stepper.value)
                aCell.valueLabel.text = readableString(value)
                self.danmakuModel.onChangeDanmakuOffsetTime(value)
            }
            return cell
        case .danmakuDensity:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.titleLabel.text = type.title
            cell.step = 1
            let model = SliderTableViewCell.Model(maxValue: 10,
                                                  minValue: 1,
                                                  currentValue: Float(self.danmakuModel.danmakuDensity))
            model.minValueFormattingCallBack = { aModel in
                return String(format: "%.0f%%", aModel.minValue * 10)
            }
            
            model.maxValueFormattingCallBack = { aModel in
                return String(format: "%.0f%%", aModel.maxValue * 10)
            }
            
            model.currentValueFormattingCallBack = { aModel in
                return String(format: "%.0f%%", aModel.currentValue * 10)
            }
            
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.value
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.danmakuModel.onChangeDanmakuDensity(currentValue)
            }
            return cell
        case .loadDanmaku, .searchDanmaku:
            let cell = tableView.dequeueCell(class: TitleMoreTableViewCell.self, indexPath: indexPath)
            cell.label.text = type.title
            return cell
        case .mergeSameDanmaku:
            let cell = tableView.dequeueCell(class: SwitchTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.aSwitch.isOn = self.danmakuModel.isMergeSameDanmaku
            cell.titleLabel.text = type.title
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                self.danmakuModel.onChangeIsMergeSameDanmaku(isOn)
            }
            return cell
        case .filterDanmaku:
            let cell = tableView.dequeueCell(class: TitleMoreTableViewCell.self, indexPath: indexPath)
            cell.label.text = type.title
            return cell
        case .danmakuEffectStyle:
            let cell = tableView.dequeueCell(class: SheetTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.valueLabel.text = self.danmakuModel.danmakuEffectStyle.title
            return cell
        case .openDanmakuRandomColor:
            let cell = tableView.dequeueCell(class: SwitchTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.aSwitch.isOn = self.danmakuModel.openDanmakuRandomColor
            cell.titleLabel.text = type.title
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                self.danmakuModel.onOpenDanmakuRandomColor(isOn)
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let type = self.dataSource[indexPath.section].dataSource[indexPath.row]

        if type == .danmakuInfo {
            self.delegate?.showDanmakuListInDanmakuSettingViewController(vc: self)
        } else if type == .loadDanmaku {
            self.delegate?.loadDanmakuFileInDanmakuSettingViewController(vc: self)
        } else if type == .searchDanmaku {
            self.delegate?.searchDanmakuInDanmakuSettingViewController(vc: self)
        } else if type == .danmakuArea {
            let vc = UIAlertController(title: type.title, message: nil, preferredStyle: .actionSheet)
            let actions = DanmakuAreaType.allCases.compactMap { (mode) -> UIAlertAction? in
                return UIAlertAction(title: mode.title, style: .default) { (UIAlertAction) in
                    self.danmakuModel.onChangeDanmakuArea(mode)
                    self.tableView.reloadData()
                }
            }
            
            for action in actions {
                vc.addAction(action)
            }
            
            vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
                
            }))
            
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        } else if type == .filterDanmaku {
            self.delegate?.filterDanmakuInDanmakuSettingViewController(vc: self)
        } else if type == .danmakuEffectStyle {
            let vc = UIAlertController(title: type.title, message: nil, preferredStyle: .actionSheet)
            let actions = DanmakuEffectStyle.allCases.compactMap { (style) -> UIAlertAction? in
                return UIAlertAction(title: style.title, style: .default) { (UIAlertAction) in
                    self.danmakuModel.onChangeDanmaEffectStyle(style)
                    self.tableView.reloadData()
                }
            }
            
            for action in actions {
                vc.addAction(action)
            }
            
            vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
                
            }))
            
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        }
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
