//
//  SettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/3.
//

import UIKit
import ANXLog

extension SettingViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let activityViewController = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        self.present(activityViewController, animated: true, completion: nil)
    }
}

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
        case .subtitleLoadOrder:
            let cell = tableView.dequeueCell(class: TitleDetailMoreTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
            return cell
        case .host:
            let cell = tableView.dequeueCell(class: TitleDetailOpertationTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
            cell.button.setTitle(NSLocalizedString("备用地址", comment: ""), for: .normal)
            cell.touchButtonCallBack = { [weak self] aCell in
                guard let self = self else { return }
                
                aCell.isShowLoading = true
                
                self.resolverAddress { ips in
                    aCell.isShowLoading = false
                    
                    
                    if let ips = ips, !ips.isEmpty {
                        let vc = UIAlertController(title:  NSLocalizedString("使用备用地址", comment: ""), message: nil, preferredStyle: .alert)
                        
                        vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
                            
                        }))
                        
                        for ip in ips {
                            vc.addAction(.init(title: ip, style: .destructive, handler: { (_) in
                                Preferences.shared.host = ip
                                self.tableView.reloadData()
                            }))
                        }
                        
                        self.present(vc, atView: aCell)
                    }

                }
            }
            return cell
        case .log:
            let cell = tableView.dequeueCell(class: TitleDetailTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = type.subtitle
            return cell
        case .cleanupCache:
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
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        } else if type == .host {
            let vc = UIAlertController(title: type.title, message: nil, preferredStyle: .alert)
            weak var aTextField: UITextField?
            vc.addTextField { textField in
                textField.keyboardType = .numberPad
                textField.placeholder = NSLocalizedString("例：\(DefaultHost)", comment: "")
                textField.text = Preferences.shared.host
                aTextField = textField
            }

            vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
                
            }))
            
            vc.addAction(.init(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { (_) in
                
                let host = aTextField?.text ?? ""

                Preferences.shared.host = host.isEmpty ? DefaultHost : host
                self.tableView.reloadData()
            }))
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        } else if type == .subtitleLoadOrder {
            let vc = SubtitleOrderViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        } else if type == .log {
            let vc = UIDocumentPickerViewController(documentTypes: [String("public.data")], in: .import)
            vc.delegate = self
            vc.allowsMultipleSelection = true
            if #available(iOS 13.0, *) {
                vc.directoryURL = URL(fileURLWithPath: ANXLogHelper.logPath())
            }
            self.present(vc, animated: true)
        } else if type == .cleanupCache {
            let vc = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: NSLocalizedString("确定清除缓存吗？", comment: ""), preferredStyle: .alert)

            vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
                
            }))
            
            vc.addAction(.init(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { (_)  in
                CacheManager.shared.cleanupCache()
            }))
            
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        }
    }
    
}

class SettingViewController: ViewController {

    private enum CellType: CaseIterable {
        case fastMatch
        case autoLoadCustomDanmaku
        case danmakuCacheDay
        case subtitleLoadOrder
        case host
        case log
        case cleanupCache
        
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
            case .log:
                return NSLocalizedString("日志", comment: "")
            case .cleanupCache:
                return NSLocalizedString("清除缓存", comment: "")
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
            case .log:
                return "将.xlog文件提供给开发者"
            case .cleanupCache:
                return "清除本地匹配记录、弹幕缓存等"
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
        tableView.registerNibCell(class: TitleDetailMoreTableViewCell.self)
        tableView.registerNibCell(class: TitleDetailOpertationTableViewCell.self)
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tableView.reloadData()
    }
    
    private func resolverAddress(completion: @escaping(([String]?) -> Void)) {
        NetworkManager.shared.getBackupIps { res, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.view.showError(error)
                    completion(nil)
                }
            } else {
                let ips = res?.answers.compactMap({ $0.data })
                DispatchQueue.main.async {
                    completion(ips)
                }
            }
        }
    }

}

