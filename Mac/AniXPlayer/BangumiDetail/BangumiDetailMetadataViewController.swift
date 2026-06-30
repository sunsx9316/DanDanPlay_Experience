//
//  BangumiDetailMetadataViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

class BangumiDetailMetadataViewController: ViewController, NSTableViewDataSource, NSTableViewDelegate {

    private enum SectionType: Int, CaseIterable {
        case titles
        case metadata
        case onlineDatabases
    }

    private var titles: [BangumiTitle] = []
    private var metaData: [String] = []
    private var onlineDatabases: [BangumiOnlineDatabase] = []

    func configure(metaData: [String], titles: [BangumiTitle], onlineDatabases: [BangumiOnlineDatabase]) {
        self.metaData = metaData
        self.titles = titles
        self.onlineDatabases = onlineDatabases
        tableView.reloadData()
    }

    private lazy var tableView: TableView = {
        let tv = TableView()
        tv.dataSource = self
        tv.delegate = self
        tv.backgroundColor = .backgroundColor
        tv.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("metadata"))
        column.width = 500
        tv.addTableColumn(column)
        return tv
    }()

    private lazy var scrollView: ScrollView<TableView> = {
        let sv = ScrollView<TableView>()
        sv.containerView = tableView
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.drawsBackground = false
        return sv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("作品详情", comment: "")

        tableView.registerClassCell(class: MetadataCellView.self)

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return titles.count + metaData.count + onlineDatabases.count
    }

    private func sectionAndRow(at row: Int) -> (SectionType, Int) {
        if row < titles.count {
            return (.titles, row)
        }
        let metaStart = titles.count
        if row < metaStart + metaData.count {
            return (.metadata, row - metaStart)
        }
        let dbStart = metaStart + metaData.count
        return (.onlineDatabases, row - dbStart)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.dequeueReusableCell(class: MetadataCellView.self)

        let (section, sectionRow) = sectionAndRow(at: row)
        switch section {
        case .titles:
            let title = titles[sectionRow]
            cell.configure(title: title.title, detail: title.language)
        case .metadata:
            cell.configure(title: metaData[sectionRow], detail: nil)
        case .onlineDatabases:
            let db = onlineDatabases[sectionRow]
            cell.configure(title: db.name, detail: db.url)
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let (section, _) = sectionAndRow(at: row)
        switch section {
        case .titles, .onlineDatabases:
            return 50
        case .metadata:
            return 36
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let (section, sectionRow) = sectionAndRow(at: row)
        switch section {
        case .titles:
            let text = titles[sectionRow].title
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .metadata:
            let text = metaData[sectionRow]
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .onlineDatabases:
            let db = onlineDatabases[sectionRow]
            if let url = URL(string: db.url) {
                NSWorkspace.shared.open(url)
            }
        }
        return false
    }
}

