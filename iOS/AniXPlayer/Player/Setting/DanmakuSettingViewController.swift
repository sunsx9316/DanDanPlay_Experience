//
//  DanmakuSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/20.
//

import UIKit
import SnapKit
import RxSwift

protocol DanmakuSettingViewControllerDelegate: AnyObject {
    
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController)
    
    func searchDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController)
}

class DanmakuSettingViewController: ViewController {
    
    private var dataSource: [DanmakuSettingType] {
        return self.danmakuModel.danmakuSetting
    }
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: SliderTableViewCell.self)
        tableView.registerNibCell(class: SwitchTableViewCell.self)
        tableView.registerNibCell(class: StepTableViewCell.self)
        tableView.registerNibCell(class: TitleTableViewCell.self)
        tableView.registerNibCell(class: SheetTableViewCell.self)
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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.dataSource[indexPath.row]
        
        switch type {
        case .danmakuAlpha:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.valueSlider.isContinuous = true
            cell.selectionStyle = .none
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
            let model = SliderTableViewCell.Model(maxValue: 3,
                                                  minValue: 1,
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
            cell.valueLabel.text = "\(Int(danmakuOffsetTime))s"
            cell.onTouchStepperCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let value = Int(aCell.stepper.value)
                aCell.valueLabel.text = "\(value)s"
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
            let cell = tableView.dequeueCell(class: TitleTableViewCell.self, indexPath: indexPath)
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
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let type = self.dataSource[indexPath.row]
        
        if type == .loadDanmaku {
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
        }
    }
    
}
