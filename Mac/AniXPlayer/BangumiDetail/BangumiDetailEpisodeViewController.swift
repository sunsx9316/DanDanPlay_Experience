//
//  BangumiDetailEpisodeViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

class BangumiDetailEpisodeViewController: ViewController, NSTableViewDataSource, NSTableViewDelegate {

    var dataSource: [BangumiEpisode] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    private lazy var tableView: TableView = {
        let tv = TableView()
        tv.dataSource = self
        tv.delegate = self
        tv.backgroundColor = .backgroundColor
        tv.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("episode"))
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

        title = NSLocalizedString("分集信息", comment: "")

        tableView.registerClassCell(class: EpisodeCellView.self)

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return dataSource.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.dequeueReusableCell(class: EpisodeCellView.self)
        let episode = dataSource[row]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var detail = "第\(episode.episodeNumber)集"
        if let lastWatched = episode.lastWatched {
            detail += " · " + String(format: NSLocalizedString("上次观看: %@", comment: ""), formatter.string(from: lastWatched))
        }
        if let airDate = episode.airDate {
            detail += " · " + String(format: NSLocalizedString("播出: %@", comment: ""), formatter.string(from: airDate))
        }

        cell.configure(title: episode.episodeTitle, detail: detail)
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 50
    }
}

