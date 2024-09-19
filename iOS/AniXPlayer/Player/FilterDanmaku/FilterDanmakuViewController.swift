//
//  FilterDanmakuViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/14.
//

import UIKit
import SnapKit
import RxSwift

extension FilterDanmakuViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = self.dataSource?[indexPath.row]
        
        let cell = tableView.dequeueCell(class: FilterDanmakuTableViewCell.self, indexPath: indexPath)
        cell.titleLabel.text = model?.text
        cell.aSwitch.isOn = model?.isEnable == true
        if model?.isRegularExp == true {
            cell.subtitleButton.setTitle(NSLocalizedString("✅正则表达式", comment: ""), for: .normal)
        } else {
            cell.subtitleButton.setTitle(NSLocalizedString("☑️正则表达式", comment: ""), for: .normal)
        }
        cell.onTouchSwitchCallBack = { [weak self] aCell in
            if var model = model {
                var newDataSource = self?.dataSource
                model.isEnable = aCell.aSwitch.isOn
                newDataSource?[indexPath.row] = model
                self?.danmakuModel.onChangeFilterDanmkus(newDataSource)
            }
        }
        
        cell.onTouchSubtitleButtonCallBack = { [weak self] aCell in
            if var model = model {
                model.isRegularExp.toggle()
                var newDataSource = self?.dataSource
                newDataSource?[indexPath.row] = model
                self?.danmakuModel.onChangeFilterDanmkus(newDataSource)
                self?.tableView.reloadData()
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if tableView.isEditing {
            return .delete
        }
        return .none
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let dataSource = self.dataSource {
                self.danmakuModel.onRemoveFilterDanmkus(dataSource[indexPath.row])
            }
        }
    }
}

class FilterDanmakuViewController: ViewController {
    
    private var dataSource: [FilterDanmaku]? {
        return self.danmakuModel.filterDanmakus
    }
    
    private let danmakuModel: PlayerDanmakuModel!
    
    private lazy var bag = DisposeBag()
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: FilterDanmakuTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()
    
    init(danmakuModel: PlayerDanmakuModel) {
        self.danmakuModel = danmakuModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("弹幕过滤列表", comment: "")
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        let addItem = UIBarButtonItem(imageName: "Public/add", target: self, action: #selector(onTouchAddItem(_:)))
        let editItem = UIBarButtonItem(title: NSLocalizedString("编辑", comment: ""), target: self, action: #selector(onTouchEditItem(_:)))
        
        editItem.setTitleTextAttributes([.font : UIFont.ddp_large,
                                                   .foregroundColor : UIColor.navigationTitleColor], for: .normal)
        editItem.setTitleTextAttributes([.font : UIFont.ddp_large,
                                                   .foregroundColor : UIColor.black], for: .highlighted)
        
        self.navigationItem.rightBarButtonItems = [addItem, editItem]
        
        self.danmakuModel.context.filterDanmakus.subscribe(onNext: { [weak self] _ in
            self?.tableView.reloadData()
        }).disposed(by: self.bag)
    }

    //MARK: Private Method
    @objc private func onTouchAddItem(_ item: UIBarButtonItem) {
        let vc = UIAlertController(title: NSLocalizedString("添加屏蔽弹幕", comment: ""), message: NSLocalizedString("支持正则表达式", comment: ""), preferredStyle: .alert)
        
        weak var aTextField: UITextField?
        vc.addTextField { textField in
            aTextField = textField
        }

        vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
            
        }))
        
        vc.addAction(.init(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { (_) in
            
            guard let text = aTextField?.text,
                  !text.isEmpty else {
                return
            }
            
            self.danmakuModel.onAddFilterDanmku(text)
        }))
        
        self.present(vc, atItem: item)
    }
    
    @objc private func onTouchEditItem(_ item: UIBarButtonItem) {
        if self.tableView.isEditing {
            item.title = NSLocalizedString("编辑", comment: "")
        } else {
            item.title = NSLocalizedString("完成", comment: "")
        }
        self.tableView.setEditing(!self.tableView.isEditing, animated: true)
    }
}
