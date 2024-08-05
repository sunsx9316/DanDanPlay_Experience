//
//  SubtitleOrderViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/14.
//

import UIKit
import SnapKit
import RxSwift

extension SubtitleOrderViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let name = self.dataSource?[indexPath.row]
        
        let cell = tableView.dequeueCell(class: EditableTableViewCell.self, indexPath: indexPath)
        cell.titleLabel.text = name
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
    
//    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
//        return false
//    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if var dataSource = self.dataSource {
            let movedObject = dataSource[sourceIndexPath.row]
            dataSource.remove(at: sourceIndexPath.row)
            dataSource.insert(movedObject, at: destinationIndexPath.row)
            self.globalSettingModel.onChangeSubtitleLoadOrder(dataSource)
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if var dataSource = self.dataSource {
                dataSource.remove(at: indexPath.row)
                self.globalSettingModel.onChangeSubtitleLoadOrder(dataSource)
            }
        }
    }
}

class SubtitleOrderViewController: ViewController {
    
    private var dataSource: [String]? {
        return self.globalSettingModel.subtitleLoadOrder
    }
    
    private let globalSettingModel: GlobalSettingModel!
    
    private lazy var bag = DisposeBag()
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: EditableTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()
    
    init(globalSettingModel: GlobalSettingModel) {
        self.globalSettingModel = globalSettingModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("字幕加载顺序", comment: "")
        
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
        
        self.globalSettingModel.context.subtitleLoadOrder.subscribe(onNext: { [weak self] _ in
            self?.tableView.reloadData()
        }).disposed(by: self.bag)
    }

    //MARK: Private Method
    @objc private func onTouchAddItem(_ item: UIBarButtonItem) {
        let vc = UIAlertController(title: NSLocalizedString("添加字幕关键字", comment: ""), message: NSLocalizedString("播放器会优先选择关键字靠前的字幕加载", comment: ""), preferredStyle: .alert)
        
        weak var aTextField: UITextField?
        vc.addTextField { textField in
            textField.placeholder = NSLocalizedString("如：简中", comment: "")
            aTextField = textField
        }

        vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
            
        }))
        
        vc.addAction(.init(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { (_) in
            
            guard let text = aTextField?.text,
                  !text.isEmpty else {
                return
            }

            var subtitleLoadOrder = self.globalSettingModel.subtitleLoadOrder ?? []
            
            if !subtitleLoadOrder.contains(text) {
                subtitleLoadOrder.insert(text, at: 0)
                self.globalSettingModel.onChangeSubtitleLoadOrder(subtitleLoadOrder)
            }
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
