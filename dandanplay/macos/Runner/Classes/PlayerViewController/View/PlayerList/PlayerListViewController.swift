//
//  PlayerListViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/3/8.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa
import dandanplay_native

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

class PlayerListViewController: NSViewController, NSMenuDelegate, NSTableViewDelegate, NSTableViewDataSource {
    
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet var popMenu: NSMenu!
    private lazy var cellHeightDic: [Int : CGFloat] = {
        return [Int : CGFloat]()
    }()
    
    weak var delegate: PlayerListViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        popMenu.removeAllItems()
        popMenu.addItem(NSMenuItem(title: "删除", action: #selector(onClickDeleteItem(_:)), keyEquivalent: ""))
    }
    
    func reloadData() {
        cellHeightDic.removeAll()
        tableView.reloadData()
    }
    
    //MARK: NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return delegate?.numberOfRowAtPlayerListViewController() ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.dequeueReusableCell(withNibClass: PlayerListTableViewCell.self)
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
    
    //MARK: NSMenuDelegate
    func menuWillOpen(_ menu: NSMenu) {
        if tableView.selectedRowIndexes.isEmpty {
            menu.cancelTrackingWithoutAnimation()
        }
    }
    
    //MARK: Private Method
    @objc private func onClickDeleteItem(_ item: NSMenuItem) {
        delegate?.playerListViewController(self, didDeleteRowIndexSet: tableView.selectedRowIndexes)
        tableView.reloadData()
    }
    
    @IBAction func onDoubleClickTableRow(_ sender: NSTableView) {
        delegate?.playerListViewController(self, didSelectedRow: sender.selectedRow)
    }
}
