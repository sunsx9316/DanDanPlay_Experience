//
//  BaseLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa
import SnapKit


class BaseLoginHistoryViewController<F: File>: ViewController, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate {

    weak var navigator: MediaLibraryNavigation?
    var onSelectFile: ((File, [File]) -> Void)?

    var dataSource: [LoginInfo] {
        get { return [] }
        set { }
    }

    private lazy var scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.documentView = tableView
        return sv
    }()

    lazy var tableView: NSTableView = {
        let tv = NSTableView()
        tv.delegate = self
        tv.dataSource = self
        tv.headerView = nil
        tv.rowHeight = 50
        tv.selectionHighlightStyle = .regular
        tv.enableRowHoverTracking()

        tv.menu = .init()
        tv.menu?.delegate = self

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cell"))
        col.width = 460
        tv.addTableColumn(col)

        return tv
    }()

    private lazy var addButton: NSButton = {
        let btn = NSButton(title: "+", target: self, action: #selector(onTouchAddButton))
        btn.font = NSFont.ddp_large()
        btn.bezelStyle = .rounded
        btn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return btn
    }()

    private lazy var titleLabel: NSTextField = {
        let tf = NSTextField(labelWithString: NSLocalizedString("登录历史", comment: ""))
        tf.font = NSFont.ddp_small(weight: .semibold)
        tf.textColor = .secondaryLabelColor
        return tf
    }()

    private lazy var backButton: NSButton = {
        let btn = NSButton(title: NSLocalizedString("← 返回", comment: ""), target: self, action: #selector(onTouchBackButton))
        btn.bezelStyle = .inline
        btn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        let headerStack = NSStackView(views: [backButton, titleLabel, addButton])
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

        tableView.reloadData()
    }

    func jumpToConnectViewController(_ loginInfo: LoginInfo? = nil) {
        let vc = BaseConnectSvrViewController(loginInfo: loginInfo, fileManager: F.fileManager)
        vc.navigator = navigator
        vc.onSuccessConnected = { [weak self] loginInfo in
            guard let self = self else { return }
            var loginInfos = self.dataSource
            if let index = loginInfos.firstIndex(where: { $0 == loginInfo }) {
                loginInfos[index] = loginInfo
            } else {
                loginInfos.append(loginInfo)
            }
            self.dataSource = loginInfos
            self.tableView.reloadData()

            let browser = FileBrowserViewController(rootFile: F.rootFile, selectedFile: nil, filterType: .video)
            browser.navigator = self.navigator
            browser.onSelectFile = self.onSelectFile
            self.navigator?.pushViewController(browser)
        }
        navigator?.pushViewController(vc)
    }

    // MARK: - Actions

    @objc private func onTouchAddButton() {
        jumpToConnectViewController()
    }

    @objc private func onTouchBackButton() {
        navigator?.popViewController()
    }

    // MARK: - NSTableViewDelegate, NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return dataSource.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let info = dataSource[row]
        let cellId = NSUserInterfaceItemIdentifier("LoginHistoryCell")
        var cell = tableView.makeView(withIdentifier: cellId, owner: nil) as? LoginHistoryCellView

        if cell == nil {
            cell = LoginHistoryCellView()
            cell?.identifier = cellId
        }

        cell?.titleLabel.stringValue = info.url.host ?? ""
        let userName = info.auth?.userName ?? ""
        cell?.detailLabel.stringValue = userName
        cell?.detailLabel.isHidden = userName.isEmpty
        let remark = info.remark ?? ""
        cell?.remarkLabel.stringValue = remark
        cell?.remarkLabel.isHidden = remark.isEmpty
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < dataSource.count else { return }
        tableView.deselectAll(nil)

        let loginInfo = dataSource[row]

        view.showLoading(statusText: NSLocalizedString("连接中...", comment: ""))
        F.fileManager.connectWithLoginInfo(loginInfo) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.view.dismiss(delay: 0)
                if let error = error {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.view.window!)
                } else {
                    var loginInfos = self.dataSource
                    if let index = loginInfos.firstIndex(of: loginInfo) {
                        loginInfos.remove(at: index)
                    }
                    loginInfos.insert(loginInfo, at: 0)
                    self.dataSource = loginInfos
                    self.tableView.reloadData()

                    let browser = FileBrowserViewController(rootFile: F.rootFile, selectedFile: nil, filterType: .video)
                    browser.navigator = self.navigator
                    browser.onSelectFile = self.onSelectFile
                    self.navigator?.pushViewController(browser)
                }
            }
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.themedRowView(forRow: row)
    }
    // MARK: - NSMenuDelegate
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(withTitle: NSLocalizedString("编辑", comment: ""), action: #selector(onClickEditMenu(_:)), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("删除", comment: ""), action: #selector(onClickDeleteMenu(_:)), keyEquivalent: "")
    }

    @objc private func onClickEditMenu(_ item: NSMenuItem) {
        let row = tableView.clickedRow
        guard row >= 0, row < dataSource.count else { return }
        jumpToConnectViewController(dataSource[row])
    }

    @objc private func onClickDeleteMenu(_ item: NSMenuItem) {
        let row = tableView.clickedRow
        guard row >= 0, row < dataSource.count else { return }
        var loginInfos = dataSource
        loginInfos.remove(at: row)
        dataSource = loginInfos
        tableView.reloadData()
    }
}

// MARK: - LoginHistoryCellView

private class LoginHistoryCellView: NSTableCellView {

    let titleLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.font = NSFont.ddp_small()
        return tf
    }()

    let detailLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.font = NSFont.ddp_small()
        tf.textColor = .secondaryLabelColor
        return tf
    }()

    let remarkLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.font = NSFont.ddp_small()
        tf.textColor = .secondaryLabelColor
        return tf
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let stack = NSStackView(views: [titleLabel, detailLabel, remarkLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
