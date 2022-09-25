//
//  PlayerListViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/3/8.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa

protocol PlayerListViewControllerDelegate: AnyObject {
    func numberOfRowAtPlayerListViewController() -> Int
    func playerListViewController(_ viewController: PlayerListViewController, titleAtRow: Int) -> String
    func playerListViewController(_ viewController: PlayerListViewController, didSelectedRow: Int)
    func playerListViewController(_ viewController: PlayerListViewController, didDeleteRowIndexSet: IndexSet)
    func currentPlayIndexAtPlayerListViewController(_ viewController: PlayerListViewController) -> Int?
}

extension PlayerListViewControllerDelegate {
    func playerListViewController(_ viewController: PlayerListViewController, didSelectedRow: Int) {
        
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, didDeleteRowIndexSet: IndexSet) {
        
    }
    
    func currentPlayIndexAtPlayerListViewController(_ viewController: PlayerListViewController) -> Int? {
        return nil
    }
}

class PlayerListViewController: ViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    
    private lazy var scrollView: ScrollView<TableView> = {
        let tableView = TableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.target = self
        tableView.doubleAction = #selector(onDoubleClickTableRow(_:))
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("删除", comment: ""), action: { [weak self] _ in
            guard let self = self else { return }
            
            self.delegate?.playerListViewController(self, didDeleteRowIndexSet: tableView.selectedRowIndexes)
            self.scrollView.containerView.reloadData()
        }))
        
        tableView.menu = menu
        
        var scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()
    
    private lazy var cellHeightDic: [Int : CGFloat] = {
        return [Int : CGFloat]()
    }()
    
    weak var delegate: PlayerListViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
    }
    
    func reloadData() {
        cellHeightDic.removeAll()
        self.scrollView.containerView.reloadData()
    }
    
    //MARK: NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return delegate?.numberOfRowAtPlayerListViewController() ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.dequeueCell(nibClass: PlayerListTableViewCell.self)
        cell.string = delegate?.playerListViewController(self, titleAtRow: row)
        cell.showPoint = delegate?.currentPlayIndexAtPlayerListViewController(self) == row
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        
        if let height = cellHeightDic[row] {
            return height
        }
        
        if let title = delegate?.playerListViewController(self, titleAtRow: row) {
            let isCurrentIndex = delegate?.currentPlayIndexAtPlayerListViewController(self) == row
            
            var width = view.frame.width
            if isCurrentIndex {
                width -= 27
            } else {
                width -= 14
            }
            
            let height = (title as NSString).height(for: NSFont.systemFont(ofSize: 14), width: width) + 10
            cellHeightDic[row] = height
            return height
        }
        return 16
    }
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 500))
    }
    
    //MARK: Private Method
    
    @objc private func onDoubleClickTableRow(_ sender: NSTableView) {
        delegate?.playerListViewController(self, didSelectedRow: sender.selectedRow)
    }
}
