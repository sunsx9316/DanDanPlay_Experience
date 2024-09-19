//
//  FilterDanmakuViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/9/17.
//

import AppKit
import RxSwift
import SnapKit

extension FilterDanmakuViewController: NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        menu.addItem(withTitle: NSLocalizedString("添加弹幕屏蔽词", comment: ""), action: #selector(onTouchAddItem(_:)), keyEquivalent: "")
        if self.scrollView.containerView.clickedRow >= 0 {
            menu.addItem(withTitle: NSLocalizedString("删除", comment: ""), action: #selector(onClickDeleteItem(_:)), keyEquivalent: "")
        }
    }
}

extension FilterDanmakuViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var model = self.dataSource[row]
        
        let cell = tableView.dequeueReusableCell(class: FilterDanmakuTableViewCell.self)
        cell.titleLabel.text = model.text
        cell.aSwitch.isOn = model.isEnable
        cell.checkbox.state = model.isRegularExp ? .on : .off
        cell.checkbox.title = NSLocalizedString("正则表达式", comment: "")
        cell.onClickCheckCallBack = { [weak self] aCell in
            var newDataSource = self?.dataSource
            model.isRegularExp = aCell.checkbox.state == .on
            newDataSource?[row] = model
            self?.danmakuModel.onChangeFilterDanmkus(newDataSource)
        }
        
        cell.onClickSwitchCallBack = { [weak self] aCell in
            var newDataSource = self?.dataSource
            model.isEnable = aCell.aSwitch.state == .on
            newDataSource?[row] = model
            self?.danmakuModel.onChangeFilterDanmkus(newDataSource)
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 38
    }
}

class FilterDanmakuViewController: ViewController {

    private var dataSource: [FilterDanmaku] {
        return self.danmakuModel.filterDanmakus ?? []
    }
    
    private let danmakuModel: PlayerDanmakuModel!
    
    private lazy var bag = DisposeBag()
    
    init(danmakuModel: PlayerDanmakuModel) {
        self.danmakuModel = danmakuModel
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 500))
    }
    
    private lazy var scrollView: ScrollView<TableView> = {
        let tableView = TableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowSizeStyle = .custom
        tableView.registerNibCell(class: FilterDanmakuTableViewCell.self)
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)
        
        tableView.menu = .init()
        tableView.menu?.delegate = self
        
        let scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("右键编辑", comment: "")
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        self.danmakuModel.context.filterDanmakus.subscribe(onNext: { [weak self] _ in
            self?.scrollView.containerView.reloadData()
        }).disposed(by: self.bag)
    }

    //MARK: Private Method
    @objc private func onTouchAddItem(_ item: NSMenuItem) {
        let vc = NSAlert()
        vc.messageText = NSLocalizedString("添加弹幕屏蔽词", comment: "")
        vc.alertStyle = .informational
        vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
        vc.addButton(withTitle: NSLocalizedString("取消", comment: ""))
        
        let aTextField = TextField(frame: .init(x: 0, y: 0, width: 150, height: 25))
        aTextField.placeholderString = NSLocalizedString("如：NMSL", comment: "")
        vc.accessoryView = aTextField
        
        let response: NSApplication.ModalResponse = vc.runModal()
        
        if response == .alertFirstButtonReturn {
            guard let text = aTextField.text,
                  !text.isEmpty else {
                return
            }

            self.danmakuModel.onAddFilterDanmku(text)
        }
    }
    
    @objc private func onClickDeleteItem(_ item: NSMenuItem) {
        let row = self.scrollView.containerView.clickedRow
        
        if row < 0 || row >= self.dataSource.count {
            return
        }
        
        let model = self.dataSource[row]
        self.danmakuModel.onRemoveFilterDanmkus(model)
    }
}
