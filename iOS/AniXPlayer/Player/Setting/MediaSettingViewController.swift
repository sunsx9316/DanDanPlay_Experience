//
//  MediaSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/22.
//

import UIKit

protocol MediaSettingViewControllerDelegate: AnyObject {
    
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController)
    
}

class MediaSettingViewController: ViewController {
    
    private lazy var dataSource = [MediaSettingInfo]()
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: SliderTableViewCell.self)
        tableView.registerNibCell(class: SwitchTableViewCell.self)
        tableView.registerNibCell(class: SheetTableViewCell.self)
        tableView.registerNibCell(class: TitleTableViewCell.self)
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
    
    private var mediaModel: PlayerMediaModel {
        return self.playerModel.mediaModel
    }
    
    private var playerModel: PlayerModel!
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm:ss"
        return dateFormatter
    }()
    
    weak var delegate: MediaSettingViewControllerDelegate?
    
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
        reloadData()
    }

    private func reloadData() {
        self.dataSource = self.mediaModel.mediaSetting
        self.tableView.reloadData()
    }
}


extension MediaSettingViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.dataSource[section].title
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.dataSource[indexPath.section].dataSource[indexPath.row]
        
        switch type {
        case .subtitleSafeArea:
            let cell = tableView.dequeueCell(class: SwitchTableViewCell.self, indexPath: indexPath)
            cell.aSwitch.isOn = self.mediaModel.subtitleSafeArea
            cell.titleLabel.text = type.title
            cell.selectionStyle = .none
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                self.mediaModel.onChangeSubtitleSafeArea(isOn)
            }
            return cell
        case .playerSpeed:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.selectionStyle = .none
            let model = SliderTableViewCell.Model(maxValue: 3,
                                                  minValue: 0.5,
                                                  currentValue: Float(self.mediaModel.playerSpeed))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.value
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.mediaModel.onChangePlayerSpeed(Double(currentValue))
            }
            return cell
        case .playerMode:
            let cell = tableView.dequeueCell(class: SheetTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.valueLabel.text = self.mediaModel.playerMode.title
            return cell
        case .loadSubtitle:
            let cell = tableView.dequeueCell(class: TitleTableViewCell.self, indexPath: indexPath)
            cell.label.text = type.title
            return cell
        case .subtitleTrack:
            let cell = tableView.dequeueCell(class: SheetTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.valueLabel.text = self.mediaModel.currentSubtitle?.subtitleName ?? NSLocalizedString("无", comment: "")
            return cell
        case .audioTrack:
            let cell = tableView.dequeueCell(class: SheetTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.valueLabel.text = self.mediaModel.currentAudioChannel?.audioName ?? NSLocalizedString("无", comment: "")
            return cell
        case .autoJumpTitleEnding:
            let cell = tableView.dequeueCell(class: SwitchTableViewCell.self, indexPath: indexPath)
            cell.aSwitch.isOn = self.mediaModel.autoJumpTitleEnding
            cell.titleLabel.text = type.title
            cell.selectionStyle = .none
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                
                self.mediaModel.onChangeAutoJumpTitleEnding(isOn)
                self.reloadData()
            }
            return cell
        case .jumpTitleDuration:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.selectionStyle = .none
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
                
                let currentValue = aCell.valueSlider.value
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.mediaModel.onChangeJumpTitleDuration(Double(currentValue))
            }
            return cell
        case .jumpEndingDuration:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.selectionStyle = .none
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
                
                let currentValue = aCell.valueSlider.value
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.mediaModel.onChangeJumpEndingDuration(Double(currentValue))
            }
            return cell
        case .subtitleDelay:
            let cell = tableView.dequeueCell(class: StepTableViewCell.self, indexPath: indexPath)
            cell.selectionStyle = .none
            cell.titleLabel.text = type.title
            let offsetTime = self.mediaModel.subtitleOffsetTime
            cell.stepper.minimumValue = -500
            cell.stepper.maximumValue = 500
            cell.stepper.value = Double(offsetTime)
            cell.valueLabel.text = "\(Int(offsetTime))s"
            cell.onTouchStepperCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let value = Int(aCell.stepper.value)
                aCell.valueLabel.text = "\(value)s"
                
                self.mediaModel.onChangeSubtitleOffsetTime(value)
            }
            return cell
        case .subtitleMargin:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.selectionStyle = .none
            cell.step = 1
            let model = SliderTableViewCell.Model(maxValue: 1000,
                                                  minValue: 0,
                                                  currentValue: Float(self.mediaModel.subtitleMargin))
            
            cell.model = model
            
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = Int(aCell.valueSlider.value)
                let model = aCell.model
                model?.currentValue = Float(currentValue)
                aCell.model = model
                
                self.mediaModel.onChangeSubtitleMargin(currentValue)
            }
            return cell
        case .subtitleFontSize:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.selectionStyle = .none
            cell.step = 1
            let model = SliderTableViewCell.Model(maxValue: 500,
                                                  minValue: 10,
                                                  currentValue: Float(self.mediaModel.subtitleFontSize))
            
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.value
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                
                self.mediaModel.onChangeSubtitleFontSize(currentValue)
            }
            return cell
        case .matchInfo:
            let cell = tableView.dequeueCell(class: TitleTableViewCell.self, indexPath: indexPath)
            cell.backgroundView?.backgroundColor = .clear
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            cell.label.font = .ddp_normal
            if let media = self.mediaModel.media {
                let matchInfo = self.mediaModel.matchInfo(media: media)
                cell.label.text = matchInfo?.matchDesc
            } else {
                cell.label.text = NSLocalizedString("无", comment: "")
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let type = self.dataSource[indexPath.section].dataSource[indexPath.row]
        
        if type == .playerMode {
            let vc = UIAlertController(title: type.title, message: nil, preferredStyle: .actionSheet)
            let actions = PlayerMode.allCases.compactMap { (mode) -> UIAlertAction? in
                return UIAlertAction(title: mode.title, style: .default) { (UIAlertAction) in
                    self.onTouchAlertAction(mode)
                }
            }
            
            for action in actions {
                vc.addAction(action)
            }
            
            vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
                
            }))
            
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        } else if type == .loadSubtitle {
            self.delegate?.loadSubtitleFileInMediaSettingViewController(self)
        } else if type == .subtitleTrack {
            
            if self.mediaModel.media == nil  {
                return
            }
            
            let localSubtitleList = self.mediaModel.subtitleList
            
            //本地没有字幕，不响应。
            if localSubtitleList.isEmpty {
                return
            }
            
            let vc = UIAlertController(title: type.title, message: nil, preferredStyle: .actionSheet)
            
            //加载本地字幕
            for subtitle in localSubtitleList {
                let action = UIAlertAction(title: subtitle.subtitleName, style: .default) { (UIAlertAction) in
                    DispatchQueue.main.async {
                        self.mediaModel.currentSubtitle = subtitle
                        self.tableView.reloadData()
                    }
                }
                vc.addAction(action)
            }
            
            vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in }))
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        } else if type == .audioTrack {
            let audioChannelList = self.mediaModel.audioChannelList
            guard !audioChannelList.isEmpty else { return }
            
            let vc = UIAlertController(title: type.title, message: nil, preferredStyle: .actionSheet)
            
            let actions = audioChannelList.compactMap { (mode) -> UIAlertAction? in
                return UIAlertAction(title: mode.audioName, style: .default) { (UIAlertAction) in
                    self.mediaModel.currentAudioChannel = mode
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
    
    private func onTouchAlertAction(_ type: PlayerMode) {
        self.mediaModel.onChangePlayerMode(type)
        self.tableView.reloadData()
    }
    
}
