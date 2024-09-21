//
//  SettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/3.
//

import UIKit
import ANXLog
import RxSwift

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
            cell.aSwitch.isOn = self.model.fastMatch
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            cell.selectionStyle = .none
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                let isOn = aCell.aSwitch.isOn
                self?.model.onOpenFastMatch(isOn)
            }
            return cell
        case .autoLoadCustomDanmaku:
            let cell = tableView.dequeueCell(class: SwitchDetailTableViewCell.self, indexPath: indexPath)
            cell.aSwitch.isOn = self.model.autoLoadCustomDanmaku
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            cell.selectionStyle = .none
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                let isOn = aCell.aSwitch.isOn
                self?.model.onOpenAutoLoadCustomDanmaku(isOn)
            }
            return cell
        case .autoLoadCustomSubtitle:
            let cell = tableView.dequeueCell(class: SwitchDetailTableViewCell.self, indexPath: indexPath)
            cell.aSwitch.isOn = self.model.autoLoadCustomSubtitle
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            cell.selectionStyle = .none
            cell.onTouchSliderCallBack = { [weak self] (aCell) in
                let isOn = aCell.aSwitch.isOn
                self?.model.onOpenAutoLoadCustomSubtitle(isOn)
            }
            return cell
        case .danmakuCacheDay:
            let cell = tableView.dequeueCell(class: TitleDetailTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            return cell
        case .subtitleLoadOrder:
            let cell = tableView.dequeueCell(class: TitleDetailMoreTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            return cell
        case .host:
            let cell = tableView.dequeueCell(class: TitleDetailOpertationTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
            cell.button.setTitle(NSLocalizedString("获取备用地址", comment: ""), for: .normal)
            cell.touchButtonCallBack = { [weak self] aCell in

                aCell.isShowLoading = true
                
                _ = self?.model.backupAddress().subscribe(onNext: { ips in
                    
                    if let ips = ips, !ips.isEmpty {
                        self?.showAddressAlert(ips, at: aCell)
                    }
                    
                }, onError: { error in
                    aCell.isShowLoading = false
                    self?.view.showError(error)
                }, onCompleted: {
                    aCell.isShowLoading = false
                })
            }
            return cell
        case .log, .cleanupCache, .cleanupHistory:
            let cell = tableView.dequeueCell(class: TitleDetailTableViewCell.self, indexPath: indexPath)
            cell.titleLabel.text = type.title
            cell.subtitleLabel.text = self.model.subtitle(settingType: type)
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
                let day = max(0, self.model.danmakuCacheDay)
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

                self.model.onChangeDanmakuCacheDay(day)
            }))
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        } else if type == .host {
            let vc = UIAlertController(title: type.title, message: nil, preferredStyle: .alert)
            weak var aTextField: UITextField?
            vc.addTextField { textField in
                textField.keyboardType = .numberPad
                textField.placeholder = NSLocalizedString("例：\(DefaultHost)", comment: "")
                textField.text = self.model.host
                aTextField = textField
            }

            vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
                
            }))
            
            vc.addAction(.init(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { (_) in
                let host = aTextField?.text ?? ""
                self.model.onChangeHost(host)
            }))
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        } else if type == .subtitleLoadOrder {
            let vc = SubtitleOrderViewController(globalSettingModel: self.model)
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
                self.model.cleanupCache()
                self.view.showHUD(NSLocalizedString("清除成功！", comment: ""))
            }))
            
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        } else if type == .cleanupHistory {
            let vc = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: NSLocalizedString("确定清除播放历史吗？", comment: ""), preferredStyle: .alert)

            vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
                
            }))
            
            vc.addAction(.init(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { (_)  in
                self.model.cleanupHistory()
                self.view.showHUD(NSLocalizedString("清除成功！", comment: ""))
            }))
            
            self.present(vc, atView: tableView.cellForRow(at: indexPath))
        }
    }
    
}

class SettingViewController: ViewController {
    
    private var dataSource: [GlobalSettingType] {
        return self.model.allSettingType()
    }
    
    private lazy var model = GlobalSettingModel()
    
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
    
    private lazy var bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("设置", comment: "")
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        self.bindModel()
    }
    
    // MARK: Private
    private func bindModel() {
        self.model.context.host.subscribe(onNext: { [weak self] _ in
            self?.tableView.reloadData()
        }).disposed(by: self.bag)
        
        self.model.context.danmakuCacheDay.subscribe(onNext: { [weak self] _ in
            self?.tableView.reloadData()
        }).disposed(by: self.bag)
        
        self.model.context.host.subscribe(onNext: { [weak self] _ in
            self?.tableView.reloadData()
        }).disposed(by: self.bag)
        
        self.model.context.subtitleLoadOrder.subscribe(onNext: { [weak self] _ in
            self?.tableView.reloadData()
        }).disposed(by: self.bag)
    }
    
    private func showAddressAlert(_ address: [String], at cell: UIView) {
        let vc = UIAlertController(title:  NSLocalizedString("使用备用地址", comment: ""), message: nil, preferredStyle: .alert)
        
        vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
            
        }))
        
        for ip in address {
            vc.addAction(.init(title: ip, style: .destructive, handler: { (_) in
                self.model.onChangeHost(ip)
            }))
        }
        
        self.present(vc, atView: cell)
    }

}

