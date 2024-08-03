//
//  MediaSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/22.
//

import Cocoa

protocol MediaSettingViewControllerDelegate: AnyObject {
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController)
}

class MediaSettingViewController: ViewController {
    
    private lazy var dataSource = MediaSetting.allCases
    
    private lazy var scrollView: ScrollView<TableView> = {
        let tableView = TableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.target = self
        tableView.doubleAction = #selector(onClickTableView(_:))
        
        tableView.registerNibCell(class: SwitchTableViewCell.self)
        tableView.registerNibCell(class: SliderTableViewCell.self)
        tableView.registerNibCell(class: SheetTableViewCell.self)
        tableView.registerNibCell(class: TitleTableViewCell.self)
        tableView.registerNibCell(class: StepTableViewCell.self)
        
        var scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()

    weak var delegate: MediaSettingViewControllerDelegate?
    
    private var mediaModel: PlayerMediaModel!
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm:ss"
        return dateFormatter
    }()
    
    init(mediaModel: PlayerMediaModel) {
        self.mediaModel = mediaModel
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
        
        self.reloadDataSource()
    }
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 600))
    }

    // MARK: Private Method
    @objc private func onClickTableView(_ tableView: NSTableView) {
        
        let row = tableView.selectedRow
        if row < 0 {
            return
        }
        
        let type = self.dataSource[row]
        if type == .loadSubtitle {
           self.delegate?.loadSubtitleFileInMediaSettingViewController(self)
       }
    }
    
    private func reloadDataSource() {
        self.dataSource = self.mediaModel.mediaSetting
        self.scrollView.containerView.reloadData()
    }
}

extension MediaSettingViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let type = self.dataSource[row]
        switch type {
        case .playerSpeed:
            return 80
        case .subtitleSafeArea, .subtitleTrack, .audioTrack, .playerMode, .loadSubtitle:
            return 40
        case .autoJumpTitleEnding:
            return 40
        case .jumpTitleDuration:
            return 80
        case .jumpEndingDuration:
            return 80
        case .subtitleMargin:
            return 80
        case .subtitleFontSize:
            return 80
        case .subtitleDelay:
            return 40
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let type = self.dataSource[row]
        
        switch type {
        case .subtitleSafeArea:
            let cell = tableView.dequeueReusableCell(class: SwitchTableViewCell.self)
            cell.aSwitch.isOn = self.mediaModel.subtitleSafeArea
            cell.aSwitch.title = type.title
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                
                self.mediaModel.onChangeSubtitleSafeArea(isOn)
            }
            return cell
        case .playerSpeed:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            let model = SliderTableViewCell.Model(maxValue: 3,
                                                  minValue: 0.5,
                                                  currentValue: Float(self.mediaModel.playerSpeed))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.floatValue
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.mediaModel.onChangePlayerSpeed(Double(currentValue))
            }
            return cell
        case .playerMode:
            let cell = tableView.dequeueReusableCell(class: SheetTableViewCell.self)
            cell.titleLabel.text = type.title
            
            let allItems = PlayerMode.allCases
            let titles = allItems.compactMap { $0.title }
            cell.setItems(titles, selectedItem: self.mediaModel.playerMode.title)
            cell.onClickButtonCallBack = { [weak self] (idx) in
                guard let self = self else { return }
                
                let type = allItems[idx]
                self.scrollView.containerView.reloadData()
                
                self.mediaModel.onChangePlayerMode(type)
            }
            return cell
        case .loadSubtitle:
            let cell = tableView.dequeueReusableCell(class: TitleTableViewCell.self)
            cell.label.text = type.title
            return cell
        case .subtitleTrack:
            let cell = tableView.dequeueReusableCell(class: SheetTableViewCell.self)
            cell.titleLabel.text = type.title
            
            let allItems = self.mediaModel.subtitleList
            let titles = allItems.compactMap { $0.subtitleName }
            cell.setItems(titles, selectedItem: self.mediaModel.currentSubtitle?.subtitleName)
            cell.onClickButtonCallBack = { [weak self] (idx) in
                guard let self = self else { return }
                
                self.mediaModel.currentSubtitle = allItems[idx]
                self.scrollView.containerView.reloadData()
            }
            
            return cell
        case .audioTrack:
            let cell = tableView.dequeueReusableCell(class: SheetTableViewCell.self)
            cell.titleLabel.text = type.title
            
            let allItems = self.mediaModel.audioChannelList
            let titles = allItems.compactMap { $0.audioName }
            cell.setItems(titles, selectedItem: self.mediaModel.currentAudioChannel?.audioName)
            cell.onClickButtonCallBack = { [weak self] (idx) in
                guard let self = self else { return }
                
                self.mediaModel.currentAudioChannel = allItems[idx]
                self.scrollView.containerView.reloadData()
            }
            
            return cell
        case .autoJumpTitleEnding:
            let cell = tableView.dequeueReusableCell(class: SwitchTableViewCell.self)
            cell.aSwitch.isOn = self.mediaModel.autoJumpTitleEnding
            cell.aSwitch.title = type.title
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                self.mediaModel.onChangeAutoJumpTitleEnding(isOn)
                self.reloadDataSource()
            }
            return cell
        case .jumpTitleDuration:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.step = 1
            let model = SliderTableViewCell.Model(maxValue: 600,
                                                  minValue: 0,
                                                  currentValue: Float(self.mediaModel.jumpTitleDuration))
            
            model.minValueFormattingCallBack = { [weak self] aModel in
                guard let self = self else { return "" }
                
                let date = Date(timeIntervalSince1970: TimeInterval(aModel.minValue))
                return self.dateFormatter.string(from: date)
            }
            
            model.maxValueFormattingCallBack = { [weak self] aModel in
                guard let self = self else { return "" }
                
                let date = Date(timeIntervalSince1970: TimeInterval(aModel.maxValue))
                return self.dateFormatter.string(from: date)
            }
            
            model.currentValueFormattingCallBack = { [weak self] aModel in
                guard let self = self else { return "" }
                
                let date = Date(timeIntervalSince1970: TimeInterval(aModel.currentValue))
                return self.dateFormatter.string(from: date)
            }
            
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.floatValue
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.mediaModel.onChangeJumpTitleDuration(Double(currentValue))
            }
            return cell
        case .jumpEndingDuration:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.step = 1
            let model = SliderTableViewCell.Model(maxValue: 600,
                                                  minValue: 0,
                                                  currentValue: Float(self.mediaModel.jumpEndingDuration))
            
            model.minValueFormattingCallBack = { [weak self] aModel in
                guard let self = self else { return "" }
                
                let date = Date(timeIntervalSince1970: TimeInterval(aModel.minValue))
                return self.dateFormatter.string(from: date)
            }
            
            model.maxValueFormattingCallBack = { [weak self] aModel in
                guard let self = self else { return "" }
                
                let date = Date(timeIntervalSince1970: TimeInterval(aModel.maxValue))
                return self.dateFormatter.string(from: date)
            }
            
            model.currentValueFormattingCallBack = { [weak self] aModel in
                guard let self = self else { return "" }
                
                let date = Date(timeIntervalSince1970: TimeInterval(aModel.currentValue))
                return self.dateFormatter.string(from: date)
            }
            
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.floatValue
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.mediaModel.onChangeJumpEndingDuration(Double(currentValue))
            }
            return cell
        case .subtitleMargin:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.step = 1
            let model = SliderTableViewCell.Model(maxValue: 1000,
                                                  minValue: 0,
                                                  currentValue: Float(self.mediaModel.subtitleMargin))
            
            cell.model = model
            
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.integerValue
                let model = aCell.model
                model?.currentValue = Float(currentValue)
                aCell.model = model
                
                self.mediaModel.onChangeSubtitleMargin(currentValue)
            }
            return cell
        case .subtitleFontSize:
            let cell = tableView.dequeueReusableCell(class: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.step = 1
            let model = SliderTableViewCell.Model(maxValue: 500,
                                                  minValue: 10,
                                                  currentValue: Float(self.mediaModel.subtitleFontSize))
            
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.floatValue
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.mediaModel.onChangeSubtitleFontSize(currentValue)
            }
            return cell
        case .subtitleDelay:
            let cell = tableView.dequeueReusableCell(class: StepTableViewCell.self)
            cell.titleLabel.text = type.title
            let offsetTime = self.mediaModel.subtitleOffsetTime
            cell.stepper.minValue = -500
            cell.stepper.maxValue = 500
            cell.stepper.integerValue = offsetTime
            cell.valueLabel.text = "\(offsetTime)s"
            cell.onTouchStepperCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let value = aCell.stepper.integerValue
                aCell.valueLabel.text = "\(value)s"
                
                self.mediaModel.onChangeSubtitleOffsetTime(value)
            }
            return cell
        }
    }
    
}
