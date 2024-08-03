//
//  DanmakuSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/20.
//

import Cocoa
import SnapKit

protocol DanmakuSettingViewControllerDelegate: AnyObject {
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuAlpha alpha: Float)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuSpeed speed: Float)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuFontSize fontSize: Double)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, danmakuArea: DanmakuArea)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeShowDanmaku isShow: Bool)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuOffsetTime danmakuOffsetTime: Int)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuDensity density: Float)
    
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController)
    
    func searchDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController)
}


extension DanmakuSettingViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let type = self.dataSource[row]
        return type.rowHeight
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let type = self.dataSource[row]
        
        switch type {
        case .danmakuAlpha:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.valueSlider.isContinuous = true
            let model = SliderTableViewCell.Model(maxValue: 1,
                                                  minValue: 0,
                                                  currentValue: Float(Preferences.shared.danmakuAlpha))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.floatValue
                Preferences.shared.danmakuAlpha = Double(aCell.valueSlider.floatValue)
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                self.delegate?.danmakuSettingViewController(self, didChangeDanmakuAlpha: currentValue)
            }
            return cell
        case .danmakuFontSize:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            let model = SliderTableViewCell.Model(maxValue: 40,
                                                  minValue: 10,
                                                  currentValue: Float(Preferences.shared.danmakuFontSize))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = Int(aCell.valueSlider.floatValue)
                Preferences.shared.danmakuFontSize = Double(currentValue)
                let model = aCell.model
                model?.currentValue = Float(currentValue)
                aCell.model = model
                self.delegate?.danmakuSettingViewController(self, didChangeDanmakuFontSize: Double(currentValue))
            }
            return cell
        case .danmakuSpeed:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.valueSlider.isContinuous = true
            let model = SliderTableViewCell.Model(maxValue: 3,
                                                  minValue: 1,
                                                  currentValue: Float(Preferences.shared.danmakuSpeed))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.floatValue
                Preferences.shared.danmakuSpeed = Double(aCell.valueSlider.floatValue)
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.delegate?.danmakuSettingViewController(self, didChangeDanmakuSpeed: currentValue)
            }
            return cell
        case .danmakuProportion:
            let cell = tableView.dequeueReusableCell(class: SheetTableViewCell.self)
            cell.titleLabel.text = type.title
            let allItems = DanmakuArea.allCases
            let titles = allItems.compactMap { $0.title }
            cell.setItems(titles, selectedItem: Preferences.shared.danmakuArea.title)
            cell.onClickButtonCallBack = { (idx) in
                let type = allItems[idx]
                Preferences.shared.danmakuArea = type
                self.scrollView.containerView.reloadData()
                self.delegate?.danmakuSettingViewController(self, danmakuArea: type)
            }
            return cell
        
        case .showDanmaku:
            let cell = tableView.dequeueReusableCell(class: SwitchTableViewCell.self)
            cell.aSwitch.isOn = Preferences.shared.isShowDanmaku
            cell.aSwitch.title = type.title
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                Preferences.shared.isShowDanmaku = isOn
                self.delegate?.danmakuSettingViewController(self, didChangeShowDanmaku: isOn)
            }
            return cell
        case .danmakuOffsetTime:
            let cell = tableView.dequeueReusableCell(class: StepTableViewCell.self)
            cell.titleLabel.text = type.title
            let danmakuOffsetTime = Preferences.shared.danmakuOffsetTime
            cell.stepper.minValue = -500
            cell.stepper.maxValue = 500
            cell.stepper.integerValue = danmakuOffsetTime
            cell.valueLabel.text = "\(Int(danmakuOffsetTime))s"
            cell.onTouchStepperCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let value = Int(aCell.stepper.floatValue)
                Preferences.shared.danmakuOffsetTime = value
                aCell.valueLabel.text = "\(value)s"
                self.delegate?.danmakuSettingViewController(self, didChangeDanmakuOffsetTime: value)
            }
            return cell
        case .danmakuDensity:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.step = 1
            let model = SliderTableViewCell.Model(maxValue: 10,
                                                  minValue: 1,
                                                  currentValue: Float(Preferences.shared.danmakuDensity))
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
                Preferences.shared.danmakuDensity = currentValue
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.delegate?.danmakuSettingViewController(self, didChangeDanmakuDensity: currentValue)
            }
            return cell
        case .loadDanmaku, .searchDanmaku:
            let cell = tableView.dequeueReusableCell(class: TitleTableViewCell.self)
            cell.label.text = type.title
            return cell
        }
    }
    
}

class DanmakuSettingViewController: ViewController {
    
    private enum CellType: CaseIterable {
        case danmakuFontSize
        case danmakuSpeed
        case danmakuAlpha
        case danmakuProportion
        case danmakuDensity
        case showDanmaku
        case danmakuOffsetTime
        case searchDanmaku
        case loadDanmaku
        
        var title: String {
            switch self {
            case .danmakuFontSize:
                return NSLocalizedString("弹幕字体大小", comment: "")
            case .danmakuSpeed:
                return NSLocalizedString("弹幕速度", comment: "")
            case .danmakuAlpha:
                return NSLocalizedString("弹幕透明度", comment: "")
            case .danmakuProportion:
                return NSLocalizedString("显示区域", comment: "")
            case .showDanmaku:
                return NSLocalizedString("弹幕开关", comment: "")
            case .danmakuOffsetTime:
                return NSLocalizedString("弹幕偏移时间", comment: "")
            case .loadDanmaku:
                return NSLocalizedString("加载本地弹幕...", comment: "")
            case .searchDanmaku:
                return NSLocalizedString("搜索弹幕", comment: "")
            case .danmakuDensity:
                return NSLocalizedString("弹幕密度", comment: "")
            }
        }
        
        var rowHeight: CGFloat {
            switch self {
            case .danmakuFontSize, .danmakuSpeed, .danmakuAlpha, .danmakuProportion, .danmakuDensity:
                return 80
            case .showDanmaku, .danmakuOffsetTime, .searchDanmaku, .loadDanmaku:
                return 40
            }
        }
    }
    
    private lazy var dataSource = CellType.allCases
    
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
        }
    }

}
