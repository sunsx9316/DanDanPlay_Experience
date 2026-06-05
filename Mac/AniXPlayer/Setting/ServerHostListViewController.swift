//
//  ServerHostListViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa
import SnapKit
import RxSwift

extension ServerHostListViewController: NSTableViewDelegate, NSTableViewDataSource {

    private enum Section: Int, CaseIterable {
        case official
        case custom

        var title: String {
            switch self {
            case .official: return NSLocalizedString("官方域名", comment: "")
            case .custom: return NSLocalizedString("自定义域名", comment: "")
            }
        }
    }

    private var officialHosts: [String] {
        var hosts = [DefaultHost]
        if let backups = backupHosts {
            hosts.append(contentsOf: backups)
        }
        return hosts
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return officialHosts.count + (customHosts?.count ?? 0)
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return row == 0 || row == officialHosts.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if row == 0 || row == officialHosts.count {
            return 24
        }
        return 36
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if row == 0 {
            return makeGroupCell(tableView: tableView, title: Section.official.title, showRefresh: true)
        }

        let officialCount = officialHosts.count
        if row == officialCount {
            return makeGroupCell(tableView: tableView, title: Section.custom.title, showRefresh: false)
        }

        if row < officialCount {
            let hostIndex = row - 1
            let host = officialHosts[hostIndex]
            return makeHostCell(tableView: tableView, host: host, isSelected: host == currentHost)
        } else {
            let hostIndex = row - officialCount - 1
            guard let host = customHosts?[hostIndex] else { return nil }
            return makeHostCell(tableView: tableView, host: host, isSelected: host == currentHost)
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let officialCount = officialHosts.count
        return row != 0 && row != officialCount
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.themedRowView(forRow: row)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        let officialCount = officialHosts.count
        guard row >= 0, row != 0, row != officialCount else { return }

        let host: String
        if row < officialCount {
            host = officialHosts[row - 1]
        } else {
            let hostIndex = row - officialCount - 1
            guard let h = customHosts?[hostIndex] else { return }
            host = h
        }

        currentHost = host
        globalSettingModel.onChangeHost(host)
        tableView.reloadData()
    }

    // MARK: - Cell Factory

    private func makeGroupCell(tableView: NSTableView, title: String, showRefresh: Bool) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier("GroupCell")
        var cell = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellId

            let tf = NSTextField()
            tf.isEditable = false
            tf.isBordered = false
            tf.backgroundColor = .clear
            tf.font = .systemFont(ofSize: 11, weight: .semibold)
            tf.textColor = .secondaryLabelColor
            cell?.textField = tf
            cell?.addSubview(tf)
            tf.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(12)
                make.centerY.equalToSuperview()
            }
        }
        cell?.textField?.stringValue = title

        if showRefresh {
            var btn = cell?.subviews.compactMap({ $0 as? NSButton }).first
            if btn == nil {
                btn = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)!, target: self, action: #selector(onTouchRefresh(_:)))
                btn?.bezelStyle = .inline
                btn?.isBordered = false
                cell?.addSubview(btn!)
                btn?.snp.makeConstraints { make in
                    make.leading.equalTo(cell!.textField!.snp.trailing).offset(4)
                    make.centerY.equalToSuperview()
                    make.width.height.equalTo(16)
                }
            }
            btn?.isHidden = false
        } else {
            let btn = cell?.subviews.compactMap({ $0 as? NSButton }).first
            btn?.isHidden = true
        }

        return cell
    }

    private func makeHostCell(tableView: NSTableView, host: String, isSelected: Bool) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier("HostCell")
        var cell = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellId

            let tf = NSTextField()
            tf.isEditable = false
            tf.isBordered = false
            tf.backgroundColor = .clear
            tf.font = .systemFont(ofSize: 13)
            cell?.textField = tf
            cell?.addSubview(tf)
            tf.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(24)
                make.centerY.equalToSuperview()
                make.trailing.equalToSuperview().offset(-12)
            }
        }
        cell?.textField?.stringValue = host
        cell?.textField?.textColor = isSelected ? .mainColor : .textColor
        return cell
    }

    // MARK: - Actions

    @objc private func onTouchRefresh(_ sender: NSButton) {
        loadBackupHosts()
    }
}

class ServerHostListViewController: ViewController {

    fileprivate let globalSettingModel: GlobalSettingModel

    fileprivate var currentHost: String = Preferences.shared.host

    fileprivate var customHosts: [String]? {
        didSet { tableView.reloadData() }
    }

    fileprivate var backupHosts: [String]? {
        didSet { tableView.reloadData() }
    }

    private let bag = DisposeBag()

    private lazy var addButton: Button = {
        let btn = Button(image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil)!, target: self, action: #selector(onTouchAdd(_:)))
        btn.bezelStyle = .inline
        btn.toolTip = NSLocalizedString("添加自定义域名", comment: "")
        return btn
    }()

    private lazy var deleteButton: Button = {
        let btn = Button(image: NSImage(systemSymbolName: "minus", accessibilityDescription: nil)!, target: self, action: #selector(onTouchDelete(_:)))
        btn.bezelStyle = .inline
        btn.toolTip = NSLocalizedString("删除选中域名", comment: "")
        return btn
    }()

    private lazy var doneButton: Button = {
        let btn = Button(title: NSLocalizedString("完成", comment: ""), target: self, action: #selector(onTouchDone(_:)))
        btn.bezelStyle = .rounded
        btn.keyEquivalent = "\r"
        return btn
    }()

    private lazy var tableView: TableView = {
        let tv = TableView()
        tv.delegate = self
        tv.dataSource = self
        tv.headerView = nil
        tv.rowHeight = 36
        tv.style = .sourceList
        tv.enableRowHoverTracking()

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("host"))
        col.width = 420
        tv.addTableColumn(col)

        return tv
    }()

    private lazy var scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.documentView = tableView
        return sv
    }()

    init(globalSettingModel: GlobalSettingModel) {
        self.globalSettingModel = globalSettingModel
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 440, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("请求域名", comment: "")

        let toolbar = NSStackView(views: [addButton, deleteButton, NSView(), doneButton])
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        view.addSubview(scrollView)
        view.addSubview(toolbar)

        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        toolbar.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(44)
        }

        doneButton.snp.makeConstraints { make in
            make.width.equalTo(80)
            make.height.equalTo(28)
        }

        customHosts = Preferences.shared.customHosts

        if let cached = Preferences.shared.backupHosts {
            backupHosts = cached
        } else {
            loadBackupHosts()
        }
    }

    // MARK: - Private

    fileprivate func loadBackupHosts() {
        _ = globalSettingModel.backupAddress().subscribe(onNext: { [weak self] hosts in
            guard let self = self else { return }
            self.backupHosts = hosts
            Preferences.shared.backupHosts = hosts
        }, onError: { error in
            print("[ServerHostList] 加载备用域名失败: \(error)")
        })
    }

    @objc private func onTouchAdd(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("添加自定义域名", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("确定", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        let textField = TextField(frame: .init(x: 0, y: 0, width: 250, height: 25))
        textField.placeholderString = "http://"
        alert.accessoryView = textField

        guard let window = view.window else { return }

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self, response == .alertFirstButtonReturn else { return }

            let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            var hosts = self.customHosts ?? []
            if !hosts.contains(text) {
                hosts.insert(text, at: 0)
                Preferences.shared.customHosts = hosts
                self.customHosts = hosts
            }
        }
    }

    @objc private func onTouchDelete(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0 else { return }

        let officialCount = officialHosts.count
        guard row > officialCount else { return }

        let hostIndex = row - officialCount - 1
        guard var hosts = customHosts, hostIndex < hosts.count else { return }

        let deletedHost = hosts[hostIndex]
        if deletedHost == currentHost {
            globalSettingModel.onChangeHost(DefaultHost)
            currentHost = DefaultHost
        }

        hosts.remove(at: hostIndex)
        Preferences.shared.customHosts = hosts
        customHosts = hosts
    }

    @objc private func onTouchDone(_ sender: NSButton) {
        view.window?.close()
    }
}
