//
//  ServerHostListViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa
import SnapKit
import RxSwift

// MARK: - NSOutlineView DataSource & Delegate

extension ServerHostListViewController: NSOutlineViewDataSource, NSOutlineViewDelegate {

    private enum Section: Int, CaseIterable {
        case official
        case custom

        var title: String {
            switch self {
            case .official: return NSLocalizedString("官方域名", comment: "")
            case .custom:   return NSLocalizedString("自定义域名", comment: "")
            }
        }
    }

    private var officialHosts: [String] {
        var hosts = [DefaultHost]
        if let backups = backupHosts, !backups.isEmpty {
            hosts.append(contentsOf: backups)
        }
        return hosts
    }

    // MARK: - DataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return Section.allCases.count
        }
        guard let section = item as? Section else { return 0 }
        switch section {
        case .official: return officialHosts.count
        case .custom:   return customHosts?.count ?? 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return Section.allCases[index]
        }
        guard let section = item as? Section else { return "" }
        switch section {
        case .official: return officialHosts[index]
        case .custom:   return customHosts?[index] ?? ""
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is Section
    }

    // MARK: - Delegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let section = item as? Section {
            return makeSectionCell(outlineView: outlineView, section: section)
        }
        if let host = item as? String {
            return makeHostCell(outlineView: outlineView, host: host, isSelected: host == currentHost)
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
        return item is Section
    }

    func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return item is String
    }

    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is Section { return 24 }
        return 36
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return outlineView.themedRowView(forRow: outlineView.row(forItem: item))
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? String else { return }

        currentHost = item
        globalSettingModel.onChangeHost(item)
        outlineView.reloadData()
    }

    // MARK: - Section Header Creation

    private func makeSectionCell(outlineView: NSOutlineView, section: Section) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier("SectionCell")
        var cell = outlineView.makeView(withIdentifier: cellId, owner: nil) as? ServerHostSectionCellView
        if cell == nil {
            cell = ServerHostSectionCellView()
            cell?.identifier = cellId
            cell?.refreshButton.target = self
            cell?.refreshButton.action = #selector(onTouchRefresh(_:))
        }
        cell?.textField?.stringValue = section.title
        cell?.refreshButton.isHidden = (section != .official)
        return cell
    }

    private func makeHostCell(outlineView: NSOutlineView, host: String, isSelected: Bool) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier("HostCell")
        var cell = outlineView.makeView(withIdentifier: cellId, owner: nil) as? ServerHostCellView
        if cell == nil {
            cell = ServerHostCellView()
            cell?.identifier = cellId
        }
        cell?.textField?.stringValue = host
        cell?.textField?.textColor = isSelected ? .mainColor : .textColor
        return cell
    }
}

// MARK: - ViewController

class ServerHostListViewController: ViewController {

    fileprivate let globalSettingModel: GlobalSettingModel

    fileprivate var currentHost: String = Preferences.shared.host

    fileprivate var customHosts: [String]? {
        didSet { outlineView.reloadData() }
    }

    fileprivate var backupHosts: [String]? {
        didSet { outlineView.reloadData() }
    }

    private let bag = DisposeBag()

    private lazy var addButton: Button = {
        let btn = Button(image: NSImage.safeSystemSymbol("plus"), target: self, action: #selector(onTouchAdd(_:)))
        btn.bezelStyle = .inline
        btn.toolTip = NSLocalizedString("添加自定义域名", comment: "")
        return btn
    }()

    private lazy var deleteButton: Button = {
        let btn = Button(image: NSImage.safeSystemSymbol("minus"), target: self, action: #selector(onTouchDelete(_:)))
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

    private lazy var outlineView: OutlineView = {
        let ov = OutlineView()
        ov.dataSource = self
        ov.delegate = self
        ov.indentationPerLevel = 0
        ov.enableRowHoverTracking()

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("host"))
        col.width = 420
        ov.addTableColumn(col)

        return ov
    }()

    private lazy var scrollView: ScrollView<OutlineView> = {
        let sv = ScrollView<OutlineView>()
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.containerView = outlineView
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

        if let cached = Preferences.shared.backupHosts, !cached.isEmpty {
            backupHosts = cached
        } else {
            loadBackupHosts()
        }

        // 自动展开所有 section
        for section in Section.allCases {
            outlineView.expandItem(section)
        }
    }

    // MARK: - Actions

    fileprivate func loadBackupHosts() {
        _ = globalSettingModel.backupAddress().subscribe(onNext: { [weak self] hosts in
            guard let self = self else { return }
            self.backupHosts = hosts
            if let hosts = hosts, !hosts.isEmpty {
                Preferences.shared.backupHosts = hosts
            }
            // 刷新后重新展开
            self.outlineView.expandItem(Section.official)
        }, onError: { error in
            print("[ServerHostList] 加载备用域名失败: \(error)")
        })
    }

    @objc private func onTouchRefresh(_ sender: NSButton) {
        loadBackupHosts()
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
                self.outlineView.expandItem(Section.custom)
            }
        }
    }

    @objc private func onTouchDelete(_ sender: NSButton) {
        let row = outlineView.selectedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? String else { return }

        // 只允许删除自定义域名
        guard var hosts = customHosts, let index = hosts.firstIndex(of: item) else { return }

        if item == currentHost {
            globalSettingModel.onChangeHost(DefaultHost)
            currentHost = DefaultHost
        }

        hosts.remove(at: index)
        Preferences.shared.customHosts = hosts
        customHosts = hosts
    }

    @objc private func onTouchDone(_ sender: NSButton) {
        view.window?.close()
    }
}

