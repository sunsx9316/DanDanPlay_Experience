//
//  DanmakuSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/20.
//

import UIKit
import SnapKit

protocol DanmakuSettingViewControllerDelegate: AnyObject {
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuAlpha alpha: Float)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuSpeed speed: Float)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuFontSize fontSize: Double)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, danmakuProportion: Double)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeShowDanmaku isShow: Bool)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuOffsetTime danmakuOffsetTime: Int)
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuDensity density: Float)
    
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController)
    func searchDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController)
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
                                                  currentValue: Float(Preferences.shared.danmakuAlpha))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.value
                Preferences.shared.danmakuAlpha = Double(aCell.valueSlider.value)
                var model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                self.delegate?.danmakuSettingViewController(self, didChangeDanmakuAlpha: currentValue)
            }
            return cell
        case .danmakuFontSize:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.titleLabel.text = type.title
            let model = SliderTableViewCell.Model(maxValue: 40,
                                                  minValue: 10,
                                                  currentValue: Float(Preferences.shared.danmakuFontSize))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = Int(aCell.valueSlider.value)
                Preferences.shared.danmakuFontSize = Double(currentValue)
                var model = aCell.model
                model?.currentValue = Float(currentValue)
                aCell.model = model
                self.delegate?.danmakuSettingViewController(self, didChangeDanmakuFontSize: Double(currentValue))
            }
            return cell
        case .danmakuSpeed:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.titleLabel.text = type.title
            cell.valueSlider.isContinuous = true
            let model = SliderTableViewCell.Model(maxValue: 3,
                                                  minValue: 1,
                                                  currentValue: Float(Preferences.shared.danmakuSpeed))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.value
                Preferences.shared.danmakuSpeed = Double(aCell.valueSlider.value)
                var model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.delegate?.danmakuSettingViewController(self, didChangeDanmakuSpeed: currentValue)
            }
            return cell
        case .danmakuProportion:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.titleLabel.text = type.title
            let maxCount = Preferences.shared.danmakuMaxStoreValue
            let minCount = Preferences.shared.danmakuMinStoreValue
            let currentValue = max(Preferences.shared.danmakuStoreProportion, minCount)
            let model = SliderTableViewCell.Model(maxValue: Float(maxCount),
                                                  minValue: Float(minCount),
                                                  currentValue: Float(currentValue))
            cell.step = UInt(minCount)
            
            
            func updateCell(_ cell: SliderTableViewCell, model aModel: SliderTableViewCell.Model) {
                cell.model = aModel
                cell.maxValueLabel.text = NSLocalizedString("满屏", comment: "")
                let minRational = Rational(approximating: Double(aModel.minValue / aModel.maxValue))
                cell.minValueLabel.text = "\(minRational.numerator)/\(minRational.denominator)" + NSLocalizedString("屏", comment: "")
                
                if aModel.currentValue == aModel.maxValue {
                    cell.currentValueLabel.text = cell.maxValueLabel.text
                } else {
                    let rational = Rational(approximating: Double(aModel.currentValue / aModel.maxValue))
                    cell.currentValueLabel.text = "\(rational.numerator)/\(rational.denominator)" + NSLocalizedString("屏", comment: "")
                }
                
            }
            
            updateCell(cell, model: model)
            
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.value
                Preferences.shared.danmakuStoreProportion = Int(aCell.valueSlider.value)
                var model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                if let model = model {
                    updateCell(aCell, model: model)
                }
                
                self.delegate?.danmakuSettingViewController(self, danmakuProportion: Preferences.shared.danmakuProportion)
            }
            return cell
        
        case .showDanmaku:
            let cell = tableView.dequeueCell(class: SwitchTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.aSwitch.isOn = Preferences.shared.isShowDanmaku
            cell.titleLabel.text = type.title
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                Preferences.shared.isShowDanmaku = isOn
                self.delegate?.danmakuSettingViewController(self, didChangeShowDanmaku: isOn)
            }
            return cell
        case .danmakuOffsetTime:
            let cell = tableView.dequeueCell(class: StepTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.titleLabel.text = type.title
            let danmakuOffsetTime = Preferences.shared.danmakuOffsetTime
            cell.stepper.value = Double(danmakuOffsetTime)
            cell.stepper.minimumValue = -500
            cell.stepper.maximumValue = 500
            cell.valueLabel.text = "\(Int(danmakuOffsetTime))s"
            cell.onTouchStepperCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let value = Int(aCell.stepper.value)
                Preferences.shared.danmakuOffsetTime = value
                aCell.valueLabel.text = "\(value)s"
                self.delegate?.danmakuSettingViewController(self, didChangeDanmakuOffsetTime: value)
            }
            return cell
        case .danmakuDensity:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.titleLabel.text = type.title
            let model = SliderTableViewCell.Model(maxValue: 1,
                                                  minValue: 0.1,
                                                  currentValue: Float(Preferences.shared.danmakuDensity))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.value
                Preferences.shared.danmakuDensity = currentValue
                var model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.delegate?.danmakuSettingViewController(self, didChangeDanmakuDensity: currentValue)
            }
            return cell
        case .loadDanmaku, .searchDanmaku:
            let cell = tableView.dequeueCell(class: TitleTableViewCell.self, indexPath: indexPath)
            cell.label.text = type.title
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
                return NSLocalizedString("同屏弹幕数量", comment: "")
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
    }
    
    private lazy var dataSource = CellType.allCases
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: SliderTableViewCell.self)
        tableView.registerNibCell(class: SwitchTableViewCell.self)
        tableView.registerNibCell(class: StepTableViewCell.self)
        tableView.registerNibCell(class: TitleTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = .darkGray
        return tableView
    }()

    weak var delegate: DanmakuSettingViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .clear
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
    }


}
