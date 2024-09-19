//
//  SubtitleOrderViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/28.
//

import Cocoa
import SnapKit
import RxSwift

extension SubtitleOrderViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let addItem = NSMenuItem(title:  NSLocalizedString("添加字幕关键字", comment: ""), action: #selector(onTouchAddItem(_:)), keyEquivalent: "")
        menu.addItem(addItem)
        
        if self.scrollView.containerView.clickedRow >= 0 {
            let removeItem = NSMenuItem(title:  NSLocalizedString("删除", comment: ""), action: #selector(onClickDeleteItem(_:)), keyEquivalent: "")
            menu.addItem(removeItem)
        }
    }
}

extension SubtitleOrderViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let name = self.dataSource[row]
        
        let cell = tableView.dequeueReusableCell(class: TitleTableViewCell.self)
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
            var dataSource = self.dataSource
            
            for oldIndex in oldIndexes {
                if oldIndex < row {
                    let from = oldIndex + oldIndexOffset
                    let to = row - 1
                    let movedObject = dataSource[from]
                    
                    dataSource.remove(at: from)
                    dataSource.insert(movedObject, at: to)
                    tableView.removeRows(at: .init(integer: from), withAnimation: .slideDown)
                    tableView.insertRows(at: .init(integer: to), withAnimation: .slideDown)
                    
                    oldIndexOffset -= 1
                } else {
                    let from = oldIndex
                    let to = row + newIndexOffset
                    let movedObject = dataSource[from]
                    dataSource.remove(at: from)
                    dataSource.insert(movedObject, at: to)
                    tableView.removeRows(at: .init(integer: from), withAnimation: .slideUp)
                    tableView.insertRows(at: .init(integer: to), withAnimation: .slideUp)
                    newIndexOffset += 1
                }
            }
            tableView.endUpdates()
            self.globalSettingModel.onChangeSubtitleLoadOrder(dataSource)

            return true
        }
    
    @objc private func onClickDeleteItem(_ item: NSMenuItem) {
        let clickedRow = self.scrollView.containerView.clickedRow
        if clickedRow < 0 || clickedRow >= self.dataSource.count {
            return
        }
        
        var dataSource = self.dataSource
        dataSource.remove(at: clickedRow)
        self.globalSettingModel.onChangeSubtitleLoadOrder(dataSource)
    }
}

class SubtitleOrderViewController: ViewController {
    
    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "private.table-row")

    private var dataSource: [String] {
        return self.globalSettingModel.subtitleLoadOrder ?? []
    }
    
    private let globalSettingModel: GlobalSettingModel!
    
    private lazy var bag = DisposeBag()
    
    init(globalSettingModel: GlobalSettingModel) {
        self.globalSettingModel = globalSettingModel
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var scrollView: ScrollView<TableView> = {
        let tableView = TableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.registerForDraggedTypes([dragDropType])
        tableView.registerNibCell(class: TitleTableViewCell.self)
        
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
        
        self.globalSettingModel.context.subtitleLoadOrder.subscribe(onNext: { [weak self] _ in
            self?.scrollView.containerView.reloadData()
        }).disposed(by: self.bag)
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
                
                self.globalSettingModel.onChangeSubtitleLoadOrder(subtitleLoadOrder)
            }
        }
    }
}
