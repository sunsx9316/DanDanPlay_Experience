//
//  PlayerListViewController.swift
//  Runner
//
//  Created by JimHuang on 2020/3/8.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa
import SnapKit

protocol PlayerListViewControllerDelegate: AnyObject {
    func numberOfRowAtPlayerListViewController() -> Int
    func playerListViewController(_ viewController: PlayerListViewController, titleAtRow: Int) -> String
    func playerListViewController(_ viewController: PlayerListViewController, didSelectedRow: Int)
    func playerListViewController(_ viewController: PlayerListViewController, didDeleteRow: Int)
    func currentPlayIndexAtPlayerListViewController(_ viewController: PlayerListViewController) -> Int?
}

class PlayerListViewController: ViewController {

    /// 播放列表为空时由播放器提供「打开文件」入口。
    var onOpenFiles: (() -> Void)?

    private lazy var scrollView: ScrollView<TableView> = {
        let tableView = TableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.enableRowHoverTracking()
        tableView.registerClassCell(class: PlayerListTableViewCell.self)
        
        tableView.menu = .init()
        tableView.menu?.delegate = self
        
        var scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()

    private lazy var emptyTitleLabel: Label = {
        let label = Label(labelWithString: NSLocalizedString("播放列表为空", comment: ""))
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.setAccessibilityIdentifier(AccessibilityID.Player.playlistEmptyTitle)
        return label
    }()

    private lazy var emptyDetailLabel: Label = {
        let label = Label(labelWithString: NSLocalizedString("打开文件后会自动加入播放列表", comment: ""))
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private lazy var emptyStateStack: NSStackView = {
        let stack = NSStackView(views: [emptyTitleLabel, emptyDetailLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        return stack
    }()

    private lazy var openFileButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("打开文件", comment: ""),
            target: self,
            action: #selector(onTouchOpenFile(_:))
        )
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.setAccessibilityIdentifier(AccessibilityID.Player.playlistOpenFile)
        return button
    }()

    private lazy var footer = NSView()

    private lazy var cellHeightDic: [Int : CGFloat] = {
        return [Int : CGFloat]()
    }()
    
    weak var delegate: PlayerListViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        footer.addSubview(openFileButton)
        self.view.addSubview(self.scrollView)
        self.view.addSubview(self.emptyStateStack)
        self.view.addSubview(footer)

        self.scrollView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalTo(self.view.safeAreaLayoutGuide)
        }

        footer.snp.makeConstraints { make in
            make.top.equalTo(self.scrollView.snp.bottom)
            make.leading.trailing.bottom.equalTo(self.view.safeAreaLayoutGuide)
            make.height.equalTo(38)
        }

        openFileButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }

        self.emptyStateStack.snp.makeConstraints { make in
            make.center.equalTo(self.scrollView)
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        updateEmptyState()
    }
    
    func reloadData() {
        cellHeightDic.removeAll()
        self.scrollView.containerView.reloadData()
        updateEmptyState()
    }
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 500))
    }

    @objc private func onTouchOpenFile(_ sender: NSButton) {
        onOpenFiles?()
    }

    private func updateEmptyState() {
        let isEmpty = (delegate?.numberOfRowAtPlayerListViewController() ?? 0) == 0
        emptyStateStack.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
    }
    
    //MARK: Private Method
}

extension PlayerListViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let clickedRow = self.scrollView.containerView.clickedRow
        if clickedRow >= 0 {
            menu.addItem(NSMenuItem(title: NSLocalizedString("删除", comment: ""), action: { [weak self] _ in
                guard let self = self else { return }
                
                self.delegate?.playerListViewController(self, didDeleteRow: clickedRow)
                self.reloadData()
            }))
        }
    }
}

extension PlayerListViewController: NSTableViewDelegate, NSTableViewDataSource {
    //MARK: NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return delegate?.numberOfRowAtPlayerListViewController() ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.dequeueReusableCell(class: PlayerListTableViewCell.self)
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

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.themedRowView(forRow: row)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let row = tableView.selectedRow
        guard row >= 0 else { return }

        tableView.deselectAll(nil)
        delegate?.playerListViewController(self, didSelectedRow: row)
    }
}
