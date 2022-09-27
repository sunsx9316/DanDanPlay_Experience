//
//  GlobalSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa
import SnapKit

extension GlobalSettingViewController: NSTableViewDelegate, NSTableViewDataSource {
    
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
        case .fastMatch:
            let cell = tableView.dequeueCell(nibClass: SwitchDetailTableViewCell.self)
            cell.aSwitch.isOn = Preferences.shared.fastMatch
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
            cell.onTouchSliderCallBack = { (aCell) in
                let isOn = aCell.aSwitch.isOn
                Preferences.shared.fastMatch = isOn
            }
            return cell
        case .autoLoadCustomDanmaku:
            let cell = tableView.dequeueCell(nibClass: SwitchDetailTableViewCell.self)
            cell.aSwitch.isOn = Preferences.shared.autoLoadCustomDanmaku
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
            cell.onTouchSliderCallBack = { (aCell) in
                let isOn = aCell.aSwitch.isOn
                Preferences.shared.autoLoadCustomDanmaku = isOn
            }
            return cell
        case .danmakuCacheDay:
            let cell = tableView.dequeueCell(nibClass: TitleDetailTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
            return cell
        case .subtitleLoadOrder:
            let cell = tableView.dequeueCell(nibClass: TitleDetailTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
            return cell
        case .host:
            let cell = tableView.dequeueCell(nibClass: TitleDetailTableViewCell.self)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
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
            let day = max(0, Preferences.shared.danmakuCacheDay)
            aTextField.text = "\(day)"
            vc.accessoryView = aTextField
            
            let response: NSApplication.ModalResponse = vc.runModal()
            
            if response == .alertFirstButtonReturn {
                guard let text = aTextField.text,
                      let day = Int(text) else {
                    return
                }

                Preferences.shared.danmakuCacheDay = day
                self.scrollView.containerView.reloadData()
            }

        } else if type == .host {
            let vc = NSAlert()
            vc.messageText = type.title
            vc.alertStyle = .informational
            vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
            vc.addButton(withTitle: NSLocalizedString("取消", comment: ""))
            
            let aTextField = TextField(frame: .init(x: 0, y: 0, width: 250, height: 25))
            aTextField.placeholderString = NSLocalizedString("例：\(DefaultHost)", comment: "")
            aTextField.text = Preferences.shared.host
            vc.accessoryView = aTextField
            
            let response: NSApplication.ModalResponse = vc.runModal()
            
            if response == .alertFirstButtonReturn {
                let host = aTextField.text ?? ""
                
                Preferences.shared.host = host.isEmpty ? DefaultHost : host
                self.scrollView.containerView.reloadData()
            }
        } else if type == .subtitleLoadOrder {
            let vc = SubtitleOrderViewController()
            vc.didClockCallBack = { [weak self] in
                guard let self = self else { return }
                
                self.scrollView.containerView.reloadData()
            }
            self.presentAsModalWindow(vc)
        }
    }
    
}

class GlobalSettingViewController: ViewController {

    private enum CellType: CaseIterable {
        case fastMatch
        case autoLoadCustomDanmaku
        case danmakuCacheDay
        case subtitleLoadOrder
        case host
        
        var title: String {
            switch self {
            case .fastMatch:
                return NSLocalizedString("快速匹配弹幕", comment: "")
            case .danmakuCacheDay:
                return NSLocalizedString("弹幕缓存时间", comment: "")
            case .autoLoadCustomDanmaku:
                return NSLocalizedString("自动加载本地弹幕", comment: "")
            case .subtitleLoadOrder:
                return NSLocalizedString("字幕加载顺序", comment: "")
            case .host:
                return NSLocalizedString("请求域名", comment: "")
            }
        }
        
        var subtitle: String {
            switch self {
            case .fastMatch:
                return NSLocalizedString("关闭则手动关联", comment: "")
            case .danmakuCacheDay:
                let day = Preferences.shared.danmakuCacheDay
                let str: String
                if day <= 0 {
                    str = NSLocalizedString("不缓存", comment: "")
                } else {
                    str = String(format: "%ld天", day)
                }
                return str
            case .autoLoadCustomDanmaku:
                return NSLocalizedString("自动加载本地弹幕", comment: "")
            case .subtitleLoadOrder:
                let desc = Preferences.shared.subtitleLoadOrder?.reduce("", { result, str in
                    
                    guard let result = result, !result.isEmpty else {
                        return str
                    }
                    
                    return result + "," + str
                }) ?? ""
                
                if desc.isEmpty {
                    return NSLocalizedString("未指定", comment: "")
                }
                return desc
            case .host:
                return Preferences.shared.host
            }
        }
        
        var rowHeight: CGFloat {
            return 70
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
        
        var scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()

    weak var delegate: MediaSettingViewControllerDelegate?
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 500, height: 600))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("设置", comment: "")
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.scrollView.containerView.reloadData()
    }

}

