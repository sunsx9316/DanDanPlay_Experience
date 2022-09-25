//
//  MediaSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/22.
//

import Cocoa

private extension Preferences.PlayerMode {
    var title: String {
        switch self {
        case .notRepeat:
            return NSLocalizedString("自动播放（不循环）", comment: "")
        case .repeatCurrentItem:
            return NSLocalizedString("视频洗脑循环", comment: "")
        case .repeatAllItem:
            return NSLocalizedString("重复整个列表", comment: "")
        }
    }
}

protocol MediaSettingViewControllerDelegate: AnyObject {
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangeSubtitleSafeArea isOn: Bool)
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangePlayerSpeed speed: Double)
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangePlayerMode mode: Preferences.PlayerMode)
    
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController)
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didOpenSubtitle subtitle: SubtitleProtocol)
    
}

extension MediaSettingViewController: NSTableViewDelegate, NSTableViewDataSource {
    
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
        case .subtitleSafeArea:
            let cell = tableView.dequeueCell(nibClass: SwitchTableViewCell.self)
            cell.aSwitch.isOn = Preferences.shared.subtitleSafeArea
            cell.aSwitch.title = type.title
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                Preferences.shared.subtitleSafeArea = isOn
                self.delegate?.mediaSettingViewController(self, didChangeSubtitleSafeArea: isOn)
            }
            return cell
        case .playerSpeed:
            let cell = tableView.dequeueCell(nibClass: SliderTableViewCell.self)
            cell.titleLabel.text = type.title
            let model = SliderTableViewCell.Model(maxValue: 3,
                                                  minValue: 0.5,
                                                  currentValue: Float(Preferences.shared.playerSpeed))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.floatValue
                Preferences.shared.playerSpeed = Double(currentValue)
                let model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                self.delegate?.mediaSettingViewController(self, didChangePlayerSpeed: Double(currentValue))
            }
            return cell
        case .playerMode:
            let cell = tableView.dequeueCell(nibClass: SheetTableViewCell.self)
            cell.titleLabel.text = type.title
            
            let allItems = Preferences.PlayerMode.allCases
            let titles = allItems.compactMap { $0.title }
            cell.setItems(titles, selectedItem: Preferences.shared.playerMode.title)
            cell.onClickButtonCallBack = { (idx) in
                let type = allItems[idx]
                Preferences.shared.playerMode = type
                self.scrollView.containerView.reloadData()
                self.delegate?.mediaSettingViewController(self, didChangePlayerMode: type)
            }
            return cell
        case .loadSubtitle:
            let cell = tableView.dequeueCell(nibClass: TitleTableViewCell.self)
            cell.label.text = type.title
            return cell
        case .subtitleTrack:
            let cell = tableView.dequeueCell(nibClass: SheetTableViewCell.self)
            cell.titleLabel.text = type.title
            
            let allItems = self.player?.subtitleList ?? []
            let titles = allItems.compactMap { $0.name }
            cell.setItems(titles, selectedItem: self.player?.currentSubtitle?.name)
            cell.onClickButtonCallBack = { [weak self] (idx) in
                guard let self = self else { return }
                
                self.player?.currentSubtitle = allItems[idx]
                self.scrollView.containerView.reloadData()
            }
            
            return cell
        case .audioTrack:
            let cell = tableView.dequeueCell(nibClass: SheetTableViewCell.self)
            cell.titleLabel.text = type.title
            
            let allItems = self.player?.audioChannelList ?? []
            let titles = allItems.compactMap { $0.name }
            cell.setItems(titles, selectedItem: self.player?.currentAudioChannel?.name)
            cell.onClickButtonCallBack = { [weak self] (idx) in
                guard let self = self else { return }
                
                self.player?.currentAudioChannel = allItems[idx]
                self.scrollView.containerView.reloadData()
            }
            
            return cell
        }
    }
    
}

class MediaSettingViewController: ViewController {

    private enum CellType: CaseIterable {
        case subtitleSafeArea
        case subtitleTrack
        case audioTrack
        case playerSpeed
        case playerMode
        case loadSubtitle
        
        var title: String {
            switch self {
            case .subtitleSafeArea:
                return NSLocalizedString("防挡字幕", comment: "")
            case .playerSpeed:
                return NSLocalizedString("播放速度", comment: "")
            case .playerMode:
                return NSLocalizedString("播放模式", comment: "")
            case .loadSubtitle:
                return NSLocalizedString("加载本地字幕...", comment: "")
            case .subtitleTrack:
                return NSLocalizedString("字幕轨道", comment: "")
            case .audioTrack:
                return NSLocalizedString("音频轨道", comment: "")
            }
        }
        
        var rowHeight: CGFloat {
            switch self {
            case .playerSpeed:
                return 80
            case .subtitleSafeArea, .subtitleTrack, .audioTrack, .playerMode, .loadSubtitle:
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
        tableView.doubleAction = #selector(onClickTableView(_:))
        
        var scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()
    
    private weak var player: MediaPlayer?

    weak var delegate: MediaSettingViewControllerDelegate?
    
    
    init(player: MediaPlayer?) {
        self.player = player
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
    }
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 340))
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
}
