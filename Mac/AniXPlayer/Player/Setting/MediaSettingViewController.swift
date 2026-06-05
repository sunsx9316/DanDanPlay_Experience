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
        tableView.enableRowHoverTracking()

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
    
    private weak var fontPanel: NSPanel?
    
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
        
        NSFontManager.shared.isEnabled = true
        self.reloadDataSource()
    }
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 600))
    }
    
    deinit {
        NSFontPanel.shared.close()
    }

    // MARK: Private Method
    
    private func reloadDataSource() {
        self.dataSource = self.mediaModel.mediaSetting
        self.scrollView.containerView.reloadData()
        self.scrollView.containerView.expandItem(nil, expandChildren: true)
    }
}

extension MediaSettingViewController: NSFontChanging {
    func changeFont(_ sender: NSFontManager?) {
        guard let sender = sender else { return }
        let oldFont = NSFont(name: self.mediaModel.subtitleFontName, size: self.mediaModel.subtitleFontSize) ?? NSFont.systemFont(ofSize: self.mediaModel.subtitleFontSize)
        let selectedFont = sender.convert(oldFont)
        self.mediaModel.onChangeSubtitleFont(selectedFont)
        self.mediaModel.onChangeSubtitleFontSize(Float(selectedFont.pointSize))
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
        } else if let type = item as? MediaSettingType {
            switch type {
            case .playerSpeed, .jumpTitleDuration, .jumpEndingDuration, .subtitleYPosition, .subtitleFontSize, .subtitleFont:
                return 80
            case .subtitleSafeArea, .subtitleTrack, .audioTrack,
                    .playerMode, .loadSubtitle, .subtitleDelay,
                    .matchInfo, .audioDelay, .autoJumpTitleEnding,
                    .subtitleColor, .subtitleStyle, .aspectRatio, .playerPiP:
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
        } else if let type = item as? MediaSettingType {
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
                let range = self.mediaModel.playerSpeedRange()
                cell.step = range.step
                let model = SliderTableViewCell.Model(maxValue: range.max,
                                                      minValue: range.min,
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
                    self.scrollView.containerView.expandItem(item, expandChildren: true)
                    
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
                    self.scrollView.containerView.expandItem(item, expandChildren: true)
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
                    self.scrollView.containerView.expandItem(item, expandChildren: true)
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
                let range = self.mediaModel.jumpTitleDurationRange()
                
                cell.step = range.step
                let model = SliderTableViewCell.Model(maxValue: range.max,
                                                      minValue: range.min,
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
                let range = self.mediaModel.jumpEndDurationRange()
                
                cell.step = range.step
                let model = SliderTableViewCell.Model(maxValue: range.max,
                                                      minValue: range.min,
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
            case .subtitleYPosition:
                let cell = outlineView.dequeueReusableCell(class: SliderTableViewCell.self)
                cell.titleLabel.text = type.title
                let range = self.mediaModel.subtitleYPositionRange()

                cell.step = range.step
                let model = SliderTableViewCell.Model(maxValue: range.max,
                                                      minValue: range.min,
                                                      currentValue: self.mediaModel.subtitleYPosition)

                cell.model = model

                cell.onChangeSliderCallBack = { [weak self] (aCell) in
                    guard let self = self else { return }

                    let currentValue = aCell.valueSlider.floatValue
                    let model = aCell.model
                    model?.currentValue = currentValue
                    aCell.model = model

                    self.mediaModel.onChangeSubtitleYPosition(currentValue)
                }
                return cell
            case .subtitleFontSize:
                let cell = outlineView.dequeueReusableCell(class: SliderTableViewCell.self)
                cell.titleLabel.text = type.title
                let range = self.mediaModel.subtitleFontSizeRange()
                
                cell.step = range.step
                let model = SliderTableViewCell.Model(maxValue: range.max,
                                                      minValue: range.min,
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
                let range = self.mediaModel.subtitleDelayRange()
                
                cell.stepper.minValue = range.min
                cell.stepper.maxValue = range.max
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
            case .audioDelay:
                let cell = outlineView.dequeueReusableCell(class: StepTableViewCell.self)
                cell.titleLabel.text = type.title
                let offsetTime = self.mediaModel.audioOffsetTime
                let range = self.mediaModel.audioDelayRange()
                
                cell.stepper.minValue = range.min
                cell.stepper.maxValue = range.max
                cell.stepper.integerValue = offsetTime
                cell.valueLabel.text = "\(offsetTime)s"
                cell.onTouchStepperCallBack = { [weak self] (aCell) in
                    guard let self = self else { return }
                    
                    let value = aCell.stepper.integerValue
                    aCell.valueLabel.text = "\(value)s"
                    
                    self.mediaModel.onChangeAudioOffsetTime(value)
                }
                return cell
            case .subtitleFont:
                let cell = outlineView.dequeueReusableCell(class: TitleDetailTableViewCell.self)
                cell.titleLabel.text = type.title
                cell.subtitleLabel.text = self.mediaModel.subtitleFontReadableName()
                return cell
            case .subtitleStyle:
                let cell = outlineView.dequeueReusableCell(class: SwitchTableViewCell.self)
                cell.aSwitch.isOn = Preferences.shared.subtitleStyle
                cell.aSwitch.title = type.title
                cell.onTouchSliderCallBack = { [weak self] (aCell) in
                    guard let self = self else { return }
                    self.mediaModel.onChangeSubtitleStyle(aCell.aSwitch.isOn)
                }
                return cell
            case .subtitleColor:
                let cell = outlineView.dequeueReusableCell(class: TitleDetailTableViewCell.self)
                cell.titleLabel.text = type.title
                return cell
            case .aspectRatio:
                let cell = outlineView.dequeueReusableCell(class: SheetTableViewCell.self)
                cell.titleLabel.text = type.title
                let allItems = self.mediaModel.aspectRatioList
                let titles = allItems.compactMap { $0.name }
                cell.setItems(titles, selectedItem: self.mediaModel.aspectRatio.name)
                cell.onClickButtonCallBack = { [weak self] (idx) in
                    guard let self = self else { return }
                    self.mediaModel.onChangeAspectRatio(allItems[idx])
                    self.scrollView.containerView.reloadData()
                }
                return cell
            case .playerPiP:
                let cell = outlineView.dequeueReusableCell(class: SwitchTableViewCell.self)
                cell.aSwitch.isOn = self.mediaModel.playerPiP
                cell.aSwitch.title = type.title
                cell.onTouchSliderCallBack = { [weak self] (aCell) in
                    guard let self = self else { return }
                    self.mediaModel.onChangePlayerPiP(aCell.aSwitch.isOn)
                }
                return cell
            }
        }
        
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return outlineView.themedRowView(forRow: outlineView.row(forItem: item))
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let row = outlineView.selectedRow
        guard row >= 0, let type = outlineView.item(atRow: row) as? MediaSettingType else { return }

        outlineView.deselectRow(row)

        if type == .loadSubtitle {
            self.delegate?.loadSubtitleFileInMediaSettingViewController(self)
        } else if type == .subtitleFont {
            let font = NSFont(name: self.mediaModel.subtitleFontName, size: self.mediaModel.subtitleFontSize) ?? NSFont.systemFont(ofSize: self.mediaModel.subtitleFontSize)
            NSFontManager.shared.target = self
            NSFontManager.shared.setSelectedFont(font, isMultiple: false)
            NSFontManager.shared.orderFrontFontPanel(self)
        }
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
