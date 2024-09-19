//
//  DanmakuSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/20.
//

import Cocoa
import SnapKit
import DanmakuRender

protocol DanmakuSettingViewControllerDelegate: AnyObject {
    
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController)
    
    func searchDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController)
    
    func filterDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController)
}

class DanmakuSettingViewController: ViewController {
    
    private var dataSource: [DanmakuSettingType] {
        return self.danmakuModel.danmakuSetting
    }
    
    private lazy var scrollView: ScrollView<TableView> = {
        let tableView = TableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)
        
        tableView.target = self
        tableView.doubleAction = #selector(doubleClickTableView(_:))
        tableView.registerNibCell(class: SliderTableViewCell.self)
        tableView.registerNibCell(class: SwitchTableViewCell.self)
        tableView.registerNibCell(class: StepTableViewCell.self)
        tableView.registerNibCell(class: TitleTableViewCell.self)
        tableView.registerNibCell(class: SheetTableViewCell.self)
        
        
        var scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()

    weak var delegate: DanmakuSettingViewControllerDelegate?
    
    private var danmakuModel: PlayerDanmakuModel!
    
    init(danmakuModel: PlayerDanmakuModel) {
        self.danmakuModel = danmakuModel
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        self.scrollView.containerView.reloadData()
    }

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 600))
    }
    
    @objc private func doubleClickTableView(_ tableView: NSTableView) {
        let row = tableView.selectedRow
        if row < 0 {
            return
        }
        
        let type = self.dataSource[row]

        if type == .loadDanmaku {
            self.delegate?.loadDanmakuFileInDanmakuSettingViewController(vc: self)
        } else if type == .searchDanmaku {
            self.delegate?.searchDanmakuInDanmakuSettingViewController(vc: self)
        } else if type == .filterDanmaku {
            self.delegate?.filterDanmakuInDanmakuSettingViewController(vc: self)
        }
    }

}

extension DanmakuSettingViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let type = self.dataSource[row]
        switch type {
        case .danmakuFontSize, .danmakuSpeed, .danmakuAlpha, .danmakuDensity:
            return 80
        case .showDanmaku, .danmakuOffsetTime, .searchDanmaku,
                .loadDanmaku, .danmakuArea, .mergeSameDanmaku,
                .danmakuEffectStyle, .filterDanmaku:
            return 40
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let type = self.dataSource[row]
        
        switch type {
        case .danmakuAlpha:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.valueSlider.isContinuous = true
            cell.step = 0.1
            let model = SliderTableViewCell.Model(maxValue: 1,
                                                  minValue: 0,
                                                  currentValue: Float(self.danmakuModel.danmakuAlpha))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.floatValue
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                self.danmakuModel.onChangeDanmakuAlpha(currentValue)
            }
            return cell
        case .danmakuFontSize:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.step = 1
            let model = SliderTableViewCell.Model(maxValue: 40,
                                                  minValue: 10,
                                                  currentValue: Float(self.danmakuModel.danmakuFontSize))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = Int(aCell.valueSlider.floatValue)
                let model = aCell.model
                model?.currentValue = Float(currentValue)
                aCell.model = model
                self.danmakuModel.onChangeDanmakuFontSize(Double(currentValue))
            }
            return cell
        case .danmakuSpeed:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.valueSlider.isContinuous = true
            cell.step = 0.1
            let model = SliderTableViewCell.Model(maxValue: 3,
                                                  minValue: 0.5,
                                                  currentValue: Float(self.danmakuModel.danmakuSpeed))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.floatValue
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                self.danmakuModel.onChangeDanmakuSpeed(Double(currentValue))
            }
            return cell
        case .danmakuArea:
            let cell = tableView.dequeueReusableCell(class: SheetTableViewCell.self)
            cell.titleLabel.text = type.title
            let allItems = DanmakuAreaType.allCases
            let titles = allItems.compactMap { $0.title }
            cell.setItems(titles, selectedItem: self.danmakuModel.danmakuArea.title)
            cell.onClickButtonCallBack = { [weak self] (idx) in
                guard let self = self else { return }
                
                let type = allItems[idx]
                self.danmakuModel.onChangeDanmakuArea(type)
            }
            return cell
        
        case .showDanmaku:
            let cell = tableView.dequeueReusableCell(class: SwitchTableViewCell.self)
            cell.aSwitch.isOn = self.danmakuModel.isShowDanmaku
            cell.aSwitch.title = type.title
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                self.danmakuModel.onChangeIsShowDanmaku(isOn)
            }
            return cell
        case .danmakuOffsetTime:
            let cell = tableView.dequeueReusableCell(class: StepTableViewCell.self)
            cell.titleLabel.text = type.title
            let danmakuOffsetTime = self.danmakuModel.danmakuOffsetTime
            cell.stepper.minValue = -500
            cell.stepper.maxValue = 500
            cell.stepper.integerValue = danmakuOffsetTime
            cell.valueLabel.text = "\(Int(danmakuOffsetTime))s"
            cell.onTouchStepperCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let value = Int(aCell.stepper.floatValue)
                aCell.valueLabel.text = "\(value)s"
                
                self.danmakuModel.onChangeDanmakuOffsetTime(value)
            }
            return cell
        case .danmakuDensity:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
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
                
                let currentValue = aCell.valueSlider.floatValue
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.danmakuModel.onChangeDanmakuDensity(currentValue)
            }
            return cell
        case .loadDanmaku, .searchDanmaku, .filterDanmaku:
            let cell = tableView.dequeueReusableCell(class: TitleTableViewCell.self)
            cell.label.text = type.title
            return cell
        case .mergeSameDanmaku:
            let cell = tableView.dequeueReusableCell(class: SwitchTableViewCell.self)
            cell.aSwitch.isOn = self.danmakuModel.isMergeSameDanmaku
            cell.aSwitch.title = type.title
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                self.danmakuModel.onChangeIsMergeSameDanmaku(isOn)
            }
            return cell
        case .danmakuEffectStyle:
            let cell = tableView.dequeueReusableCell(class: SheetTableViewCell.self)
            cell.titleLabel.text = type.title
            let allItems = DanmakuEffectStyle.allCases
            let titles = allItems.compactMap { $0.title }
            cell.setItems(titles, selectedItem: self.danmakuModel.danmakuEffectStyle.title)
            cell.onClickButtonCallBack = { [weak self] (idx) in
                guard let self = self else { return }
                
                let style = allItems[idx]
                self.danmakuModel.onChangeDanmaEffectStyle(style)
            }
            return cell
        }
    }
    
}
