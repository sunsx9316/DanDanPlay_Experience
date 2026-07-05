//
//  SubtitleOrderViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/28.
//

import Cocoa
import SnapKit
import RxSwift

extension SubtitleOrderViewController: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let name = self.dataSource[row]

        let cell = tableView.dequeueReusableCell(class: SubtitleOrderCellView.self)
        cell.label.text = name
        cell.onClickDeleteCallBack = { [weak self] aCell in
            guard let self = self else { return }
            let row = tableView.row(for: aCell)
            guard row >= 0, row < self.dataSource.count else { return }
            var dataSource = self.dataSource
            dataSource.remove(at: row)
            self.globalSettingModel.onChangeSubtitleLoadOrder(dataSource)
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 35
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.themedRowView(forRow: row)
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
            guard let item = dragItem.item as? NSPasteboardItem,
                  let str = item.string(forType: self.dragDropType),
                  let index = Int(str) else { return }
            oldIndexes.append(index)
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

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 400))
    }

    private lazy var scrollView: ScrollView<TableView> = {
        let tableView = TableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowSizeStyle = .custom
        tableView.registerForDraggedTypes([dragDropType])
        tableView.registerClassCell(class: SubtitleOrderCellView.self)
        tableView.enableRowHoverTracking()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)

        let scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()

    private lazy var addTextField: TextField = {
        let field = TextField()
        field.placeholderString = NSLocalizedString("如：简中", comment: "")
        field.font = .ddp_normal
        field.isBordered = false
        field.wantsLayer = true
        field.layer?.borderWidth = 1
        field.layer?.borderColor = NSColor.separatorColor.cgColor
        field.layer?.cornerRadius = 4
        field.addTarget(self, action: #selector(onClickAdd(_:)))
        return field
    }()

    private lazy var addButton: Button = {
        let button = Button(title: NSLocalizedString("添加", comment: ""), target: self, action: #selector(onClickAdd(_:)))
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("字幕优先级", comment: "")

        let bottomBar = NSView()
        self.view.addSubview(self.scrollView)
        self.view.addSubview(bottomBar)
        bottomBar.addSubview(addTextField)
        bottomBar.addSubview(addButton)

        self.scrollView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        bottomBar.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.top.equalTo(self.scrollView.snp.bottom)
            make.height.equalTo(40)
        }

        addTextField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
        }

        addButton.snp.makeConstraints { make in
            make.leading.equalTo(addTextField.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
        }

        self.globalSettingModel.context.subtitleLoadOrder.subscribe(onNext: { [weak self] _ in
            self?.scrollView.containerView.reloadData()
        }).disposed(by: self.bag)
    }

    @objc private func onClickAdd(_ sender: Any) {
        let text = (addTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        var subtitleLoadOrder = dataSource
        if !subtitleLoadOrder.contains(text) {
            subtitleLoadOrder.insert(text, at: 0)
            self.globalSettingModel.onChangeSubtitleLoadOrder(subtitleLoadOrder)
            addTextField.text = ""
        }
    }
}
