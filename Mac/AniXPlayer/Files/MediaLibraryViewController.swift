//
//  MediaLibraryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa
import SnapKit

class MediaLibraryViewController: ViewController {

    private enum CellType: CaseIterable {
        case smb
        case webDav
        case ftp
        case emby
        case jellyfin
        case pc

        var name: String {
            switch self {
            case .smb: return NSLocalizedString("SMB", comment: "")
            case .webDav: return NSLocalizedString("WebDav", comment: "")
            case .ftp: return NSLocalizedString("FTP", comment: "")
            case .pc: return NSLocalizedString("弹弹play远程访问", comment: "")
            case .emby: return NSLocalizedString("Emby", comment: "")
            case .jellyfin: return NSLocalizedString("Jellyfin", comment: "")
            }
        }

        var iconName: String {
            switch self {
            case .smb: return "PickFile/smb"
            case .webDav: return "PickFile/webdav"
            case .ftp: return "PickFile/ftp"
            case .pc: return "PickFile/computer"
            case .emby: return "PickFile/emby"
            case .jellyfin: return "PickFile/jellyfin"
            }
        }
    }

    private struct Section {
        let title: String
        let items: [CellType]
    }

    private let sections: [Section] = [
        Section(title: NSLocalizedString("文件来源", comment: ""), items: [.smb, .webDav, .ftp]),
        Section(title: NSLocalizedString("媒体服务器", comment: ""), items: [.emby, .jellyfin, .pc]),
    ]

    var onSelectFile: ((File, [File]) -> Void)?

    private lazy var scrollView: ScrollView<OutlineView> = {
        let sv = ScrollView<OutlineView>()
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.containerView = outlineView
        return sv
    }()

    private lazy var outlineView: OutlineView = {
        let ov = OutlineView()
        ov.delegate = self
        ov.dataSource = self
        ov.headerView = nil
        ov.rowHeight = 52
        ov.selectionHighlightStyle = .sourceList
        ov.indentationPerLevel = 0
        ov.enableRowHoverTracking()

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cell"))
        col.width = 460
        ov.addTableColumn(col)

        return ov
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        outlineView.expandItem(nil, expandChildren: true)
    }

    private func pushLoginHistory(for type: CellType) {
        let vc: NSViewController
        switch type {
        case .smb:
            let historyVC = SMBLoginHistoryViewController()
            historyVC.navigator = navigator
            historyVC.onSelectFile = onSelectFile
            vc = historyVC
        case .webDav:
            let historyVC = WebDavLoginHistoryViewController()
            historyVC.navigator = navigator
            historyVC.onSelectFile = onSelectFile
            vc = historyVC
        case .ftp:
            let historyVC = FTPLoginHistoryViewController()
            historyVC.navigator = navigator
            historyVC.onSelectFile = onSelectFile
            vc = historyVC
        case .emby:
            let historyVC = EmbyLoginHistoryViewController()
            historyVC.navigator = navigator
            historyVC.onSelectFile = onSelectFile
            vc = historyVC
        case .jellyfin:
            let historyVC = JellyfinLoginHistoryViewController()
            historyVC.navigator = navigator
            historyVC.onSelectFile = onSelectFile
            vc = historyVC
        case .pc:
            let historyVC = PCLoginHistoryViewController()
            historyVC.navigator = navigator
            historyVC.onSelectFile = onSelectFile
            vc = historyVC
        }
        navigator?.pushViewController(vc)
    }
}

extension MediaLibraryViewController: NSOutlineViewDelegate, NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return sections.count
        }
        if let section = item as? Section {
            return section.items.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return sections[index]
        }
        if let section = item as? Section {
            return section.items[index]
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is Section
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return item is Section
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is Section {
            return 24
        }
        return 52
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let section = item as? Section {
            let cellId = NSUserInterfaceItemIdentifier("SectionCell")
            var cell = outlineView.makeView(withIdentifier: cellId, owner: nil) as? MediaLibrarySectionCellView
            if cell == nil {
                cell = MediaLibrarySectionCellView()
                cell?.identifier = cellId
            }
            cell?.textField?.stringValue = section.title
            return cell
        }

        if let type = item as? CellType {
            let cellId = NSUserInterfaceItemIdentifier("Cell")
            var cell = outlineView.makeView(withIdentifier: cellId, owner: nil) as? MediaLibraryItemCellView
            if cell == nil {
                cell = MediaLibraryItemCellView()
                cell?.identifier = cellId
            }
            let image = NSImage(named: type.iconName)
            image?.isTemplate = true
            cell?.imageView?.image = image
            cell?.textField?.stringValue = type.name
            return cell
        }

        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return item is CellType
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0, let item = outlineView.item(atRow: selectedRow) as? CellType else { return }

        outlineView.deselectRow(selectedRow)
        pushLoginHistory(for: item)
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return outlineView.themedRowView(forRow: outlineView.row(forItem: item))
    }
}
