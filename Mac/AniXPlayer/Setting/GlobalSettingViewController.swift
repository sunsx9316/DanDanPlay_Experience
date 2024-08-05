//
//  GlobalSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa
import SnapKit
import RxSwift

extension GlobalSettingViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }
    
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let type = self.dataSource[row]
        
        switch type {
        case .fastMatch:
            let cell = tableView.dequeueReusableCell(class: SwitchDetailTableViewCell.self)
            cell.aSwitch.isOn = self.model.fastMatch
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                let isOn = aCell.aSwitch.isOn
                self?.model.onOpenFastMatch(isOn)
            }
            return cell
        case .autoLoadCustomDanmaku:
            let cell = tableView.dequeueReusableCell(class: SwitchDetailTableViewCell.self)
            cell.aSwitch.isOn = self.model.autoLoadCustomDanmaku
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                let isOn = aCell.aSwitch.isOn
                self?.model.onOpenAutoLoadCustomDanmaku(isOn)
            }
            return cell
        case .danmakuCacheDay:
            let cell = tableView.dequeueReusableCell(class: TitleDetailTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            return cell
        case .subtitleLoadOrder:
            let cell = tableView.dequeueReusableCell(class: TitleDetailTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            return cell
        case .host:
            let cell = tableView.dequeueReusableCell(class: TitleDetailTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            return cell
        case .autoLoadCustomSubtitle:
            let cell = tableView.dequeueReusableCell(class: SwitchDetailTableViewCell.self)
            cell.aSwitch.isOn = self.model.autoLoadCustomSubtitle
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                let isOn = aCell.aSwitch.isOn
                self?.model.onOpenAutoLoadCustomSubtitle(isOn)
            }
            return cell
        case .log, .cleanupCache, .cleanupHistory:
            let cell = tableView.dequeueReusableCell(class: TitleDetailTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            return cell
        }
    }
    
    @objc private func doubleClickTableView(_ tableView: NSTableView) {
        
        if tableView.selectedRow < 0 {
            return
        }
        
        let type = self.dataSource[tableView.selectedRow]
        
        if type == .danmakuCacheDay {
            
            let vc = NSAlert()
            vc.messageText = type.title
            vc.alertStyle = .informational
            vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
            vc.addButton(withTitle: NSLocalizedString("取消", comment: ""))
            
            let aTextField = TextField(frame: .init(x: 0, y: 0, width: 150, height: 25))
            aTextField.placeholderString = NSLocalizedString("0则不缓存", comment: "")
            let day = max(0, self.model.danmakuCacheDay)
            aTextField.text = "\(day)"
            vc.accessoryView = aTextField
            
            let response: NSApplication.ModalResponse = vc.runModal()
            
            if response == .alertFirstButtonReturn {
                guard let text = aTextField.text,
                      let day = Int(text) else {
                    return
                }

                self.model.onChangeDanmakuCacheDay(day)
            }

        } else if type == .host {
            let vc = NSAlert()
            vc.messageText = type.title
            vc.alertStyle = .informational
            vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
            vc.addButton(withTitle: NSLocalizedString("取消", comment: ""))
            
            let aTextField = TextField(frame: .init(x: 0, y: 0, width: 250, height: 25))
            aTextField.placeholderString = NSLocalizedString("例：\(DefaultHost)", comment: "")
            aTextField.text = self.model.host
            vc.accessoryView = aTextField
            
            let response: NSApplication.ModalResponse = vc.runModal()
            
            if response == .alertFirstButtonReturn {
                let host = aTextField.text ?? ""
                
                self.model.onChangeHost(host)
            }
        } else if type == .subtitleLoadOrder {
            let vc = SubtitleOrderViewController(globalSettingModel: self.model)
            self.presentAsModalWindow(vc)
        } else if type == .log {
            NSWorkspace.shared.open(URL(fileURLWithPath: ANXLogHelper.logPath()))
        } else if type == .cleanupCache {
            let vc = NSAlert()
            vc.messageText = NSLocalizedString("提示", comment: "")
            vc.informativeText = NSLocalizedString("确定清除缓存吗？", comment: "")
            vc.alertStyle = .warning
            vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
            vc.addButton(withTitle: NSLocalizedString("取消", comment: ""))
            
            let response: NSApplication.ModalResponse = vc.runModal()
            
            if response == .alertFirstButtonReturn {
                self.model.cleanupCache()
            }
        } else if type == .cleanupHistory {
            let vc = NSAlert()
            vc.messageText = NSLocalizedString("提示", comment: "")
            vc.informativeText = NSLocalizedString("确定清除播放历史吗？", comment: "")
            vc.alertStyle = .warning
            vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
            vc.addButton(withTitle: NSLocalizedString("取消", comment: ""))
            
            let response: NSApplication.ModalResponse = vc.runModal()
            
            if response == .alertFirstButtonReturn {
                self.model.cleanupCache()
            }
        }
    }
    
}

class GlobalSettingViewController: ViewController {
    
    private var dataSource: [GlobalSettingType] {
        return self.model.allSettingType()
    }
    
    private lazy var model = GlobalSettingModel()
    
    private lazy var scrollView: ScrollView<TableView> = {
        let tableView = TableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.registerNibCell(class: SwitchDetailTableViewCell.self)
        tableView.registerNibCell(class: TitleDetailTableViewCell.self)
        
        tableView.target = self
        tableView.doubleAction = #selector(doubleClickTableView(_:))
        
        var scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()

    private lazy var bag = DisposeBag()
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 500, height: 700))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("设置", comment: "")
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        bindModel()
    }
    
    // MARK: Private
    private func bindModel() {
        self.model.context.host.subscribe(onNext: { [weak self] _ in
            self?.scrollView.containerView.reloadData()
        }).disposed(by: self.bag)
        
        self.model.context.danmakuCacheDay.subscribe(onNext: { [weak self] _ in
            self?.scrollView.containerView.reloadData()
        }).disposed(by: self.bag)
        
        self.model.context.host.subscribe(onNext: { [weak self] _ in
            self?.scrollView.containerView.reloadData()
        }).disposed(by: self.bag)
        
        self.model.context.subtitleLoadOrder.subscribe(onNext: { [weak self] _ in
            self?.scrollView.containerView.reloadData()
        }).disposed(by: self.bag)
    }

}

