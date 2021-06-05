//
//  SettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/3.
//

import UIKit

extension SettingViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.dataSource[indexPath.row]
        
        switch type {
        case .fastMatch:
            let cell = tableView.dequeueCell(class: SwitchDetailTableViewCell.self, indexPath: indexPath)
            cell.aSwitch.isOn = Preferences.shared.fastMatch
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
            cell.selectionStyle = .none
            cell.onTouchSliderCallBack = { (aCell) in
                let isOn = aCell.aSwitch.isOn
                Preferences.shared.fastMatch = isOn
            }
            return cell
        case .autoLoadCustomDanmaku:
            let cell = tableView.dequeueCell(class: SwitchDetailTableViewCell.self, indexPath: indexPath)
            cell.aSwitch.isOn = Preferences.shared.autoLoadCustomDanmaku
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
            cell.selectionStyle = .none
            cell.onTouchSliderCallBack = { (aCell) in
                let isOn = aCell.aSwitch.isOn
                Preferences.shared.autoLoadCustomDanmaku = isOn
            }
            return cell
        case .danmakuCacheDay:
            let cell = tableView.dequeueCell(class: TitleDetailTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let type = self.dataSource[indexPath.item]
        
        if type == .danmakuCacheDay {
            let vc = UIAlertController(title: type.title, message: nil, preferredStyle: .alert)
            weak var aTextField: UITextField?
            vc.addTextField { textField in
                textField.keyboardType = .numberPad
                textField.placeholder = NSLocalizedString("0则不缓存", comment: "")
                let day = max(0, Preferences.shared.danmakuCacheDay)
                textField.text = "\(day)"
                aTextField = textField
            }

            vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
                
            }))
            
            vc.addAction(.init(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { (_) in
                
                guard let text = aTextField?.text,
                      let day = Int(text) else {
                    return
                }

                Preferences.shared.danmakuCacheDay = day
                self.tableView.reloadData()
            }))
            vc.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
            self.present(vc, animated: true, completion: nil)
        }
    }
    
}

class SettingViewController: ViewController {

    private enum CellType: CaseIterable {
        case fastMatch
        case autoLoadCustomDanmaku
        case danmakuCacheDay
        
        var title: String {
            switch self {
            case .fastMatch:
                return NSLocalizedString("快速匹配弹幕", comment: "")
            case .danmakuCacheDay:
                return NSLocalizedString("弹幕缓存时间", comment: "")
            case .autoLoadCustomDanmaku:
                return NSLocalizedString("自动加载本地弹幕", comment: "")
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
            }
        }
    }
    
    private lazy var dataSource = CellType.allCases
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: SwitchDetailTableViewCell.self)
        tableView.registerNibCell(class: TitleDetailTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()

    weak var delegate: MediaSettingViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("设置", comment: "")
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
    }

}

