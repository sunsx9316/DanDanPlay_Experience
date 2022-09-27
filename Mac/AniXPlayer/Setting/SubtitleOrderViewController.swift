//
//  SubtitleOrderViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/28.
//

import Cocoa
import SnapKit

extension SubtitleOrderViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let name = self.dataSource[row]
        
        let cell = tableView.dequeueCell(nibClass: TitleTableViewCell.self)
        cell.label.text = name
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 35
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            let item = NSPasteboardItem()
            item.setString(String(row), forType: self.dragDropType)
            return item
        }

        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {

            if dropOperation == .above {
                return .move
            }
            return []
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {

            var oldIndexes = [Int]()
            info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
                if let str = (dragItem.item as! NSPasteboardItem).string(forType: self.dragDropType), let index = Int(str) {
                    oldIndexes.append(index)
                }
            }

            var oldIndexOffset = 0
            var newIndexOffset = 0

            tableView.beginUpdates()
            for oldIndex in oldIndexes {
                if oldIndex < row {
                    let from = oldIndex + oldIndexOffset
                    let to = row - 1
                    let movedObject = self.dataSource[from]
                    
                    self.dataSource.remove(at: from)
                    self.dataSource.insert(movedObject, at: to)
                    tableView.removeRows(at: .init(integer: from), withAnimation: .slideDown)
                    tableView.insertRows(at: .init(integer: to), withAnimation: .slideDown)
                    
                    oldIndexOffset -= 1
                } else {
                    let from = oldIndex
                    let to = row + newIndexOffset
                    let movedObject = self.dataSource[from]
                    self.dataSource.remove(at: from)
                    self.dataSource.insert(movedObject, at: to)
                    tableView.removeRows(at: .init(integer: from), withAnimation: .slideUp)
                    tableView.insertRows(at: .init(integer: to), withAnimation: .slideUp)
                    newIndexOffset += 1
                }
            }
            tableView.endUpdates()
            Preferences.shared.subtitleLoadOrder = self.dataSource

            return true
        }
    
    @objc private func onClickDeleteItem(_ item: NSMenuItem) {
        let clickedRow = self.scrollView.containerView.clickedRow
        if clickedRow < 0 || clickedRow >= self.dataSource.count {
            return
        }
        
        self.dataSource.remove(at: clickedRow)
        Preferences.shared.subtitleLoadOrder = self.dataSource
        self.scrollView.containerView.reloadData()
    }
}

class SubtitleOrderViewController: ViewController {
    
    var didClockCallBack: (() -> Void)?
    
    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "private.table-row")

    private lazy var dataSource = Preferences.shared.subtitleLoadOrder ?? []
    
    private lazy var scrollView: ScrollView<TableView> = {
        let tableView = TableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.registerForDraggedTypes([dragDropType])
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)
        
        tableView.menu = .init()
        let addItem = NSMenuItem(title:  NSLocalizedString("添加字幕关键字", comment: ""), action: #selector(onTouchAddItem(_:)), keyEquivalent: "")
        let removeItem = NSMenuItem(title:  NSLocalizedString("删除", comment: ""), action: #selector(onClickDeleteItem(_:)), keyEquivalent: "")
        tableView.menu?.addItem(addItem)
        tableView.menu?.addItem(removeItem)
        
        var scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()
    
    deinit {
        self.didClockCallBack?()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("右键编辑", comment: "")
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
    }

    //MARK: Private Method
    @objc private func onTouchAddItem(_ item: NSMenuItem) {
        let vc = NSAlert()
        vc.messageText = NSLocalizedString("添加字幕关键字", comment: "")
        vc.informativeText = NSLocalizedString("播放器会优先选择关键字靠前的字幕加载", comment: "")
        vc.alertStyle = .informational
        vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
        vc.addButton(withTitle: NSLocalizedString("取消", comment: ""))
        
        let aTextField = TextField(frame: .init(x: 0, y: 0, width: 150, height: 25))
        aTextField.placeholderString = NSLocalizedString("如：简中", comment: "")
        vc.accessoryView = aTextField
        
        let response: NSApplication.ModalResponse = vc.runModal()
        
        if response == .alertFirstButtonReturn {
            guard let text = aTextField.text,
                  !text.isEmpty else {
                return
            }

            var subtitleLoadOrder = Preferences.shared.subtitleLoadOrder ?? []

            if !subtitleLoadOrder.contains(text) {
                subtitleLoadOrder.insert(text, at: 0)
                Preferences.shared.subtitleLoadOrder = subtitleLoadOrder
                self.dataSource = subtitleLoadOrder
                self.scrollView.containerView.reloadData()
            }
        }
    }
}
