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
    
    private lazy var dataSource = [MediaSettingInfo]()
    
    private lazy var scrollView: ScrollView<NSOutlineView> = {
        let tableView = NSOutlineView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.target = self
        tableView.doubleAction = #selector(onClickOutlineView(_:))
        
        tableView.registerNibCell(class: SwitchTableViewCell.self)
        tableView.registerNibCell(class: SliderTableViewCell.self)
        tableView.registerNibCell(class: SheetTableViewCell.self)
        tableView.registerNibCell(class: TitleTableViewCell.self)
        tableView.registerNibCell(class: StepTableViewCell.self)
        tableView.registerNibCell(class: TitleDetailTableViewCell.self)
        
        
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
        self.scrollView.containerView.expandItem(nil, expandChildren: true)
    }
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 600))
    }

    // MARK: Private Method
    @objc private func onClickOutlineView(_ outlineView: NSOutlineView) {
        
        let row = outlineView.selectedRow
        if row < 0 {
            return
        }
        
        if let type = outlineView.item(atRow: row) as? MediaSetting {
            if type == .loadSubtitle {
               self.delegate?.loadSubtitleFileInMediaSettingViewController(self)
           }
        }
    }
    
    private func reloadDataSource() {
        self.dataSource = self.mediaModel.mediaSetting
        self.scrollView.containerView.reloadData()
    }
}

extension MediaSettingViewController: NSOutlineViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        
        if item is MediaSettingInfo {
            return 40
        } else if let type = item as? MediaSetting {
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
            case .matchInfo:
                return 40
            }
        }
        
        return 0.01
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let item = item as? MediaSettingInfo {
            let cell = outlineView.dequeueReusableCell(class: TitleTableViewCell.self)
            cell.label.text = item.title
            return cell
        } else if let type = item as? MediaSetting {
            switch type {
            case .subtitleSafeArea:
                let cell = outlineView.dequeueReusableCell(class: SwitchTableViewCell.self)
                cell.aSwitch.isOn = self.mediaModel.subtitleSafeArea
                cell.aSwitch.title = type.title
                cell.onTouchSliderCallBack = { [weak self] (aCell) in
                    guard let self = self else { return }
                    
                    let isOn = aCell.aSwitch.isOn
                    
                    self.mediaModel.onChangeSubtitleSafeArea(isOn)
                }
                return cell
            case .playerSpeed:
                let cell = outlineView.dequeueReusableCell(class: SliderTableViewCell.self)
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
                let cell = outlineView.dequeueReusableCell(class: SheetTableViewCell.self)
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
                let cell = outlineView.dequeueReusableCell(class: TitleTableViewCell.self)
                cell.label.text = type.title
                return cell
            case .subtitleTrack:
                let cell = outlineView.dequeueReusableCell(class: SheetTableViewCell.self)
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
                let cell = outlineView.dequeueReusableCell(class: SheetTableViewCell.self)
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
                let cell = outlineView.dequeueReusableCell(class: SwitchTableViewCell.self)
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
                let cell = outlineView.dequeueReusableCell(class: SliderTableViewCell.self)
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
                let cell = outlineView.dequeueReusableCell(class: SliderTableViewCell.self)
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
                let cell = outlineView.dequeueReusableCell(class: SliderTableViewCell.self)
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
                let cell = outlineView.dequeueReusableCell(class: SliderTableViewCell.self)
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
                let cell = outlineView.dequeueReusableCell(class: StepTableViewCell.self)
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
            case .matchInfo:
                let cell = outlineView.dequeueReusableCell(class: TitleTableViewCell.self)
                if let media = self.mediaModel.media {
                    let matchInfo = self.mediaModel.matchInfo(media: media)
                    cell.label.text = matchInfo?.matchDesc
                    cell.label.toolTip = matchInfo?.matchDesc
                } else {
                    cell.label.text = NSLocalizedString("无", comment: "")
                    cell.label.toolTip = nil
                }
                return cell
            }
        }
        
        return nil
    }
    
}

extension MediaSettingViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item is NSNull {
            return 0
        }
        
        if let item = item as? MediaSettingInfo {
            return item.dataSource.count
        }
        
        return self.dataSource.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return self.dataSource[index]
        } else if let item = item as? MediaSettingInfo {
            return item.dataSource[index]
        }
        return NSNull()
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? MediaSettingInfo {
            return !item.dataSource.isEmpty
        }
        return false
    }
}
