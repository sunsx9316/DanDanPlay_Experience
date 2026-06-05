//
//  GlobalSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa
import SnapKit
import RxSwift
import ANXLog

extension GlobalSettingViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }
    
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 70
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.themedRowView(forRow: row)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let type = self.dataSource[row]

        switch type {
        case .fastMatch:
            let cell = tableView.dequeueReusableCell(class: SwitchDetailTableViewCell.self)
            cell.aSwitch.isOn = self.model.fastMatch
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            cell.onTouchSwitchCallBack = { [weak self] (aCell) in
                let isOn = aCell.aSwitch.isOn
                self?.model.onOpenFastMatch(isOn)
            }
            return cell
        case .autoLoadCustomDanmaku:
            let cell = tableView.dequeueReusableCell(class: SwitchDetailTableViewCell.self)
            cell.aSwitch.isOn = self.model.autoLoadCustomDanmaku
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            cell.onTouchSwitchCallBack = { [weak self] (aCell) in
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
            cell.onTouchSwitchCallBack = { [weak self] (aCell) in
                let isOn = aCell.aSwitch.isOn
                self?.model.onOpenAutoLoadCustomSubtitle(isOn)
            }
            return cell
        case .log, .cleanupCache, .cleanupHistory:
            let cell = tableView.dequeueReusableCell(class: TitleDetailTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            return cell
        case .mainColor, .playerCore, .appLanguage:
            let cell = tableView.dequeueReusableCell(class: TitleDetailTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            return cell
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }

        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }

        tableView.deselectAll(nil)

        let type = self.dataSource[selectedRow]
        
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
            let vc = ServerHostListViewController(globalSettingModel: self.model)
            self.presentAsModalWindow(vc)
        } else if type == .mainColor {
            let vc = SetMainColorViewController(globalSettingModel: self.model)
            self.presentAsModalWindow(vc)
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
                self.model.cleanupHistory()
            }
        } else if type == .playerCore {
            let vc = NSAlert()
            vc.messageText = type.title
            vc.alertStyle = .informational
            vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
            vc.addButton(withTitle: NSLocalizedString("取消", comment: ""))

            let popup = NSPopUpButton(frame: .init(x: 0, y: 0, width: 150, height: 25))
            for coreType in MediaPlayer.CoreType.allCoreType {
                popup.addItem(withTitle: coreType.displayName)
                popup.lastItem?.tag = coreType.rawValue
            }
            popup.selectItem(withTag: Preferences.shared.playerCore.rawValue)
            vc.accessoryView = popup

            let response: NSApplication.ModalResponse = vc.runModal()

            if response == .alertFirstButtonReturn {
                if let selectedItem = popup.selectedItem,
                   let coreType = MediaPlayer.CoreType(rawValue: selectedItem.tag) {
                    self.model.onChangePlayerCore(coreType)
                }
            }
        } else if type == .appLanguage {
            let vc = NSAlert()
            vc.messageText = NSLocalizedString("语言", comment: "")
            vc.alertStyle = .informational
            vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
            vc.addButton(withTitle: NSLocalizedString("取消", comment: ""))

            let popup = NSPopUpButton(frame: .init(x: 0, y: 0, width: 150, height: 25))
            for language in AppLanguage.allCases {
                popup.addItem(withTitle: language.displayName)
                popup.lastItem?.tag = language.rawValue
            }
            popup.selectItem(withTag: Preferences.shared.appLanguage.rawValue)
            vc.accessoryView = popup

            let response: NSApplication.ModalResponse = vc.runModal()

            if response == .alertFirstButtonReturn {
                if let selectedItem = popup.selectedItem,
                   let language = AppLanguage(rawValue: selectedItem.tag) {
                    self.model.onChangeAppLanguage(language)

                    // 弹出提示要求重启
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("提示", comment: "")
                    alert.informativeText = NSLocalizedString("语言切换已生效，退出后将以新语言启动", comment: "")
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: NSLocalizedString("退出", comment: ""))
                    alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

                    if alert.runModal() == .alertFirstButtonReturn {
                        NSApp.terminate(nil)
                    }
                }
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
        tableView.enableRowHoverTracking()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.registerNibCell(class: SwitchDetailTableViewCell.self)
        tableView.registerNibCell(class: TitleDetailTableViewCell.self)
        
        var scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()

    private lazy var bag = DisposeBag()
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 500, height: 700))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("全局设置", comment: "")
        
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

        self.model.context.appLanguage.subscribe(onNext: { [weak self] _ in
            self?.scrollView.containerView.reloadData()
        }).disposed(by: self.bag)

        self.model.context.playerCore.subscribe(onNext: { [weak self] _ in
            self?.scrollView.containerView.reloadData()
        }).disposed(by: self.bag)
    }

}

