//
//  MediaSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/22.
//

import UIKit

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
    
}

extension MediaSettingViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.dataSource[indexPath.row]
        
        switch type {
        case .subtitleSafeArea:
            let cell = tableView.dequeueCell(class: SwitchTableViewCell.self, indexPath: indexPath)
            cell.aSwitch.isOn = Preferences.shared.subtitleSafeArea
            cell.titleLabel.text = type.title
            cell.selectionStyle = .none
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let isOn = aCell.aSwitch.isOn
                Preferences.shared.subtitleSafeArea = isOn
                self.delegate?.mediaSettingViewController(self, didChangeSubtitleSafeArea: isOn)
            }
            return cell
        case .playerSpeed:
            let cell = tableView.dequeueCell(class: SliderTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.selectionStyle = .none
            let model = SliderTableViewCell.Model(maxValue: 3,
                                                  minValue: 0.5,
                                                  currentValue: Float(Preferences.shared.playerSpeed))
            cell.model = model
            cell.onChangeSliderCallBack = { [weak self] (aCell) in
                guard let self = self else { return }
                
                let currentValue = aCell.valueSlider.value
                Preferences.shared.playerSpeed = Double(currentValue)
                var model = aCell.model
                model?.currentValue = currentValue
                aCell.model = model
                self.delegate?.mediaSettingViewController(self, didChangePlayerSpeed: Double(currentValue))
            }
            return cell
        case .playerMode:
            let cell = tableView.dequeueCell(class: SheetTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.valueLabel.text = Preferences.shared.playerMode.title
            return cell
        case .loadSubtitle:
            let cell = tableView.dequeueCell(class: TitleTableViewCell.self, indexPath: indexPath)
            cell.label.text = type.title
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let type = self.dataSource[indexPath.item]
        
        if type == .playerMode {
            let vc = UIAlertController(title: type.title, message: nil, preferredStyle: .actionSheet)
            let actions = Preferences.PlayerMode.allCases.compactMap { (mode) -> UIAlertAction? in
                return UIAlertAction(title: mode.title, style: .default) { (UIAlertAction) in
                    self.onTouchAlertAction(mode)
                }
            }
            
            for action in actions {
                vc.addAction(action)
            }
            
            vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
                
            }))
            
            self.present(vc, animated: true, completion: nil)
        } else if type == .loadSubtitle {
            self.delegate?.loadSubtitleFileInMediaSettingViewController(self)
        }
    }
    
    private func onTouchAlertAction(_ type: Preferences.PlayerMode) {
        Preferences.shared.playerMode = type
        self.tableView.reloadData()
        self.delegate?.mediaSettingViewController(self, didChangePlayerMode: type)
    }
    
}

class MediaSettingViewController: ViewController {

    private enum CellType: CaseIterable {
        case subtitleSafeArea
        case playerSpeed
        case playerMode
        case loadSubtitle
        
        var title: String {
            switch self {
            case .subtitleSafeArea:
                return NSLocalizedString("字幕保护区域", comment: "")
            case .playerSpeed:
                return NSLocalizedString("播放速度", comment: "")
            case .playerMode:
                return NSLocalizedString("播放模式", comment: "")
            case .loadSubtitle:
                return NSLocalizedString("加载本地字幕...", comment: "")
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
        tableView.registerNibCell(class: SheetTableViewCell.self)
        tableView.registerNibCell(class: TitleTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .none
        return tableView
    }()

    weak var delegate: MediaSettingViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .clear
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
    }

}
