//
//  FileBrowserViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa
import SnapKit

import RxSwift

class FileBrowserViewController: ViewController, NSTableViewDelegate, NSTableViewDataSource {

    var onSelectFile: ((File, [File]) -> Void)?

    private let rootFile: File
    private let selectedFile: File?
    private let filterType: URLFilterType?

    private var allFiles: [File] = []
    private var fileWrappers: [_FileWrapper] = []
    private let disposeBag = DisposeBag()

    private var manager: FileManagerProtocol {
        return type(of: rootFile).fileManager
    }

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: rootFile.fileName)
        tf.font = NSFont.ddp_small(weight: .semibold)
        tf.lineBreakMode = .byTruncatingMiddle
        return tf
    }()

    private lazy var filterButton: Button = {
        let btn = Button(title: NSLocalizedString("显示全部", comment: ""), target: self, action: #selector(onTouchFilterButton))
        btn.bezelStyle = .inline
        btn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return btn
    }()

    private lazy var scrollView: ScrollView<TableView> = {
        let sv = ScrollView<TableView>()
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.containerView = tableView
        return sv
    }()

    private lazy var tableView: TableView = {
        let tv = TableView()
        tv.delegate = self
        tv.dataSource = self
        tv.headerView = nil
        tv.rowHeight = 50
        tv.selectionHighlightStyle = .regular
        tv.doubleAction = #selector(onDoubleClick)
        tv.enableRowHoverTracking()

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cell"))
        col.width = 460
        tv.addTableColumn(col)

        return tv
    }()

    private var isShowAllFile = false {
        didSet {
            filterButton.title = isShowAllFile
                ? NSLocalizedString("恢复默认", comment: "")
                : NSLocalizedString("显示全部", comment: "")
        }
    }

    private lazy var sortButton: NSPopUpButton = {
        let btn = NSPopUpButton(title: "", target: self, action: #selector(onSortChanged(_:)))
        btn.bezelStyle = .inline
        btn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return btn
    }()

    private var sortOption: FileSortOption {
        Preferences.shared.fileBrowserSortOption
    }

    private var sortAscending: Bool {
        Preferences.shared.fileBrowserSortAscending
    }

    init(rootFile: File, selectedFile: File?, filterType: URLFilterType?) {
        self.rootFile = rootFile
        self.selectedFile = selectedFile
        self.filterType = filterType
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = rootFile.fileName

        let headerStack = NSStackView(views: [titleLabel, sortButton, filterButton])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        headerStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        view.addSubview(headerStack)
        view.addSubview(scrollView)

        headerStack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(headerStack.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        rebuildSortMenu()
        beginRefreshing()
    }

    // MARK: - Private

    private func rebuildSortMenu() {
        let isEmby = rootFile is EmbyFile
        let options: [FileSortOption] = isEmby ? FileSortOption.allCases : [.default, .fileName, .fileType]
        let current = sortOption
        let ascending = sortAscending

        let menu = NSMenu()
        for option in options {
            let marker = option == current ? (ascending ? " ↑" : " ↓") : ""
            let item = NSMenuItem(title: option.displayName + marker, action: nil, keyEquivalent: "")
            item.tag = option.rawValue
            menu.addItem(item)
        }
        let savedTarget = sortButton.target
        let savedAction = sortButton.action
        sortButton.target = nil
        sortButton.action = nil
        sortButton.menu = menu
        sortButton.selectItem(withTag: current.rawValue)
        sortButton.target = savedTarget
        sortButton.action = savedAction
    }

    private func beginRefreshing() {
        let effectiveFilter = isShowAllFile ? nil : filterType
        view.showLoading(statusText: NSLocalizedString("加载中...", comment: ""))

        manager.contentsOfDirectory(at: rootFile, filterType: effectiveFilter) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.view.dismiss(delay: 0)
                switch result {
                case .success(let files):
                    let option = self.sortOption
                    let ascending = self.sortAscending
                    let sorted = files.sorted { $0.sortCompare(to: $1, option: option, ascending: ascending) }
                    self.allFiles = sorted
                    self.fileWrappers = sorted.map { _FileWrapper(file: $0) }
                    self.tableView.reloadData()
                case .failure(let error):
                    self.view.show(error: error)
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func onTouchFilterButton() {
        isShowAllFile.toggle()
        beginRefreshing()
    }

    @objc private func onSortChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem else { return }
        let newOption = FileSortOption(rawValue: selectedItem.tag) ?? .default
        if newOption == sortOption {
            Preferences.shared.fileBrowserSortAscending.toggle()
        } else {
            Preferences.shared.fileBrowserSortOption = newOption
        }
        rebuildSortMenu()
        beginRefreshing()
    }

    @objc private func onDoubleClick() {
        let row = tableView.clickedRow
        guard row >= 0, row < fileWrappers.count else { return }
        handleSelection(at: row)
    }

    private func handleSelection(at row: Int) {
        let file = fileWrappers[row].file
        switch file.type {
        case .file:
            let files = allFiles.filter { $0.type == .file }
            if let onSelectFile = onSelectFile {
                onSelectFile(file, files)
            } else {
                navigator?.popViewController()
            }
        case .folder:
            let browser = FileBrowserViewController(rootFile: file, selectedFile: selectedFile, filterType: filterType)
            browser.navigator = navigator
            browser.onSelectFile = onSelectFile
            navigator?.pushViewController(browser)
        }
    }

    // MARK: - NSTableView

    func numberOfRows(in tableView: NSTableView) -> Int {
        return fileWrappers.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let wrapper = fileWrappers[row]
        let cellId = NSUserInterfaceItemIdentifier("FileBrowserCell")
        var cell = tableView.makeView(withIdentifier: cellId, owner: nil) as? FileBrowserCellView

        if cell == nil {
            cell = FileBrowserCellView()
            cell?.identifier = cellId
        }

        cell?.configure(with: wrapper)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < fileWrappers.count else { return }
        tableView.deselectAll(nil)
        handleSelection(at: row)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.themedRowView(forRow: row)
    }
}

// MARK: - _FileWrapper

private class _FileWrapper {
    let file: File
    var type: FileType { file.type }

    init(file: File) {
        self.file = file
    }
}

// MARK: - FileBrowserCellView

private class FileBrowserCellView: NSTableCellView {

    let titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = NSFont.ddp_normal()
        tf.lineBreakMode = .byTruncatingMiddle
        return tf
    }()

    let detailLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = NSFont.ddp_small()
        tf.textColor = .secondaryLabelColor
        return tf
    }()

    private let folderIconView: ImageView = {
        let iv = ImageView()
        iv.setScaling(.aspectFit)
        iv.contentTintColor = .mainColor
        iv.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
        return iv
    }()

    private let typeLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = NSFont.ddp_small(weight: .medium)
        tf.alignment = .center
        tf.wantsLayer = true
        tf.layer?.backgroundColor = NSColor.mainColor.cgColor
        tf.layer?.cornerRadius = 4
        tf.layer?.masksToBounds = true
        return tf
    }()

    private var iconStack: NSStackView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        folderIconView.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }
        typeLabel.snp.makeConstraints { make in
            make.width.equalTo(36)
            make.height.equalTo(20)
        }

        iconStack = NSStackView(views: [folderIconView, typeLabel, titleLabel, detailLabel])
        iconStack.orientation = .horizontal
        iconStack.alignment = .centerY
        iconStack.spacing = 8
        addSubview(iconStack)

        detailLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        iconStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with wrapper: _FileWrapper) {
        let file = wrapper.file
        titleLabel.text = file.fileName

        let isFolder = wrapper.type == .folder
        folderIconView.isHidden = !isFolder
        typeLabel.isHidden = isFolder
        detailLabel.isHidden = isFolder

        if !isFolder {
            let text = file.pathExtension.isEmpty ? "?" : file.pathExtension
            let font = NSFont.ddp_small(weight: .medium)
            let offset = (typeLabel.bounds.height - font.boundingRectForFont.height) / 2
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            typeLabel.attributedStringValue = NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: NSColor.white,
                .baselineOffset: offset,
                .paragraphStyle: paragraphStyle
            ])
            let size = file.fileSize
            detailLabel.text = size > 0 ? ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file) : ""
        }
    }
}

