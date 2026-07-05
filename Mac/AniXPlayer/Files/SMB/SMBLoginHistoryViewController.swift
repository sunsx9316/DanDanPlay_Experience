//
//  SMBLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa

class SMBLoginHistoryViewController: BaseLoginHistoryViewController<SMBFile> {

    private let sectionHeaderHeight: CGFloat = 26
    private let serviceRowHeight: CGFloat = 40
    private let historyRowHeight: CGFloat = 50

    private let serviceBrowser = SMBServiceBrowser()

    private var discoveredServices: [SMBService] = []

    private enum RowType {
        case neighborHeader
        case service(SMBService)
        case historyHeader
        case history(LoginInfo)
    }

    private var rows: [RowType] {
        var result: [RowType] = []
        if !discoveredServices.isEmpty {
            result.append(.neighborHeader)
            result.append(contentsOf: discoveredServices.map { .service($0) })
        }
        if !dataSource.isEmpty {
            result.append(.historyHeader)
            result.append(contentsOf: dataSource.map { .history($0) })
        }
        return result
    }

    override var dataSource: [LoginInfo] {
        get { return Preferences.shared.smbLoginInfos ?? [] }
        set { Preferences.shared.smbLoginInfos = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = SMBFile.fileManager.desc
        tableView.registerClassCell(class: SectionHeaderCellView.self)
        tableView.registerClassCell(class: NeighborServiceCellView.self)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        startScanning()
    }

    // MARK: - Scanning

    private func startScanning() {
        serviceBrowser.startScanning { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.discoveredServices = self.serviceBrowser.discoveredServices
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Helpers

    private func connectToService(_ service: SMBService) {
        if service.addresses.isEmpty {
            navigateToConnect(address: service.name)
        } else if service.addresses.count == 1 {
            navigateToConnect(address: service.addresses[0].ip)
        } else {
            showAddressPicker(for: service)
        }
    }

    private func showAddressPicker(for service: SMBService) {
        let alert = NSAlert()
        alert.messageText = service.name
        alert.informativeText = NSLocalizedString("选择要连接的地址：", comment: "")
        alert.alertStyle = .informational

        for addr in service.addresses {
            alert.addButton(withTitle: addr.ip)
        }
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            let idx = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            guard idx >= 0, idx < service.addresses.count else { return }
            self.navigateToConnect(address: service.addresses[idx].ip)
        }
    }

    private func navigateToConnect(address: String) {
        let urlStr = "smb://\(address)"
        guard let url = URL(string: urlStr) else { return }
        let loginInfo = LoginInfo(url: url, auth: nil)
        jumpToConnectViewController(loginInfo)
    }

    // MARK: - NSTableViewDataSource / Delegate

    override func numberOfRows(in tableView: NSTableView) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rowType = rows[row]
        switch rowType {
        case .neighborHeader:
            return makeSectionCell(tableView: tableView, title: NSLocalizedString("网络邻居", comment: ""))
        case .service(let service):
            return makeServiceCell(tableView: tableView, service: service)
        case .historyHeader:
            return makeSectionCell(tableView: tableView, title: NSLocalizedString("登录历史", comment: ""))
        case .history:
            let historyIdx = historyRowIndex(for: row)
            return super.tableView(tableView, viewFor: tableColumn, row: historyIdx)
        }
    }

    override func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < rows.count else { return }
        tableView.deselectAll(nil)

        switch rows[row] {
        case .service(let service):
            connectToService(service)
        case .history(let info):
            connectToHistory(loginInfo: info)
        default:
            break
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch rows[row] {
        case .neighborHeader, .historyHeader:
            return sectionHeaderHeight
        case .service:
            return serviceRowHeight
        case .history:
            return historyRowHeight
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        switch rows[row] {
        case .neighborHeader, .historyHeader:
            return false
        default:
            return true
        }
    }

    override func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        switch rows[row] {
        case .neighborHeader, .historyHeader:
            let rv = NSTableRowView()
            rv.backgroundColor = .cellHighlightColor
            return rv
        default:
            return tableView.themedRowView(forRow: row)
        }
    }

    // MARK: - NSMenuDelegate

    override func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let row = tableView.clickedRow
        guard row >= 0, row < rows.count else { return }

        switch rows[row] {
        case .history:
            menu.addItem(withTitle: NSLocalizedString("编辑", comment: ""), action: #selector(onClickEditMenu(_:)), keyEquivalent: "")
            menu.addItem(withTitle: NSLocalizedString("删除", comment: ""), action: #selector(onClickDeleteMenu(_:)), keyEquivalent: "")
        case .service:
            menu.addItem(withTitle: NSLocalizedString("连接", comment: ""), action: #selector(connectFromMenu(_:)), keyEquivalent: "")
        default:
            break
        }
    }

    @objc private func connectFromMenu(_ item: NSMenuItem) {
        let row = tableView.clickedRow
        guard row >= 0, row < rows.count, case .service(let service) = rows[row] else { return }
        connectToService(service)
    }

    // MARK: - Cell factory

    private func makeSectionCell(tableView: NSTableView, title: String) -> NSView? {
        let cell = tableView.dequeueReusableCell(class: SectionHeaderCellView.self)
        cell.title = title
        return cell
    }

    private func makeServiceCell(tableView: NSTableView, service: SMBService) -> NSView? {
        let cell = tableView.dequeueReusableCell(class: NeighborServiceCellView.self)
        cell.titleLabel.text = service.name
        if service.didResolve {
            cell.detailLabel.text = service.addresses.map(\.ip).joined(separator: ", ")
        } else {
            cell.detailLabel.text = NSLocalizedString("解析中…", comment: "")
        }
        return cell
    }

    // MARK: - History helpers

    private func historyRowIndex(for row: Int) -> Int {
        var offset = 0
        if !discoveredServices.isEmpty {
            offset = discoveredServices.count + 2
        } else {
            offset = 1
        }
        return row - offset
    }

    private func connectToHistory(loginInfo: LoginInfo) {
        view.showLoading(statusText: NSLocalizedString("连接中...", comment: ""))
        SMBFile.fileManager.connectWithLoginInfo(loginInfo) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.view.dismiss(delay: 0)
                if let error = error {
                    self.view.show(error: error)
                } else {
                    var loginInfos = self.dataSource
                    if let index = loginInfos.firstIndex(of: loginInfo) {
                        loginInfos.remove(at: index)
                    }
                    loginInfos.insert(loginInfo, at: 0)
                    self.dataSource = loginInfos
                    self.tableView.reloadData()

                    let browser = FileBrowserViewController(rootFile: SMBFile.rootFile, selectedFile: nil, filterType: .video)
                    browser.navigator = self.navigator
                    browser.onSelectFile = self.onSelectFile
                    self.navigator?.pushViewController(browser)
                }
            }
        }
    }
}
