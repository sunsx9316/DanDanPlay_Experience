//
//  MediaLibraryViewController.swift
//  AniXPlayer
//
//  tvOS 媒体库 — 文件来源列表（按分类分区展示）
//

import UIKit

class MediaLibraryViewController: ViewController {

    private enum CellType {
        case localFile
        case smb
        case webdav
        case ftp
        case emby
        case jellyfin
        case pc

        var title: String {
            switch self {
            case .localFile: return NSLocalizedString("本地文件", comment: "")
            case .smb: return NSLocalizedString("SMB", comment: "")
            case .webdav: return NSLocalizedString("WebDAV", comment: "")
            case .ftp: return NSLocalizedString("FTP", comment: "")
            case .emby: return NSLocalizedString("Emby", comment: "")
            case .jellyfin: return NSLocalizedString("Jellyfin", comment: "")
            case .pc: return NSLocalizedString("弹弹play远程访问", comment: "")
            }
        }

        var iconName: String {
            switch self {
            case .localFile: return "internaldrive"
            case .smb: return "network"
            case .webdav: return "globe"
            case .ftp: return "externaldrive.connected.to.line.below"
            case .emby: return "play.rectangle.on.rectangle"
            case .jellyfin: return "play.tv"
            case .pc: return "desktopcomputer"
            }
        }
    }

    private struct Section {
        let title: String
        let items: [CellType]
    }

    private lazy var sections: [Section] = [
        Section(title: NSLocalizedString("文件来源", comment: ""), items: [.localFile, .smb, .webdav, .ftp]),
        Section(title: NSLocalizedString("媒体服务器", comment: ""), items: [.emby, .jellyfin, .pc]),
    ]

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: FileListCell.self)
        tv.rowHeight = 80
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("媒体库", comment: "")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = tableView
    }
}

extension MediaLibraryViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: FileListCell.self, indexPath: indexPath)
        let type = sections[indexPath.section].items[indexPath.row]
        cell.configureAsSource(title: type.title, iconName: type.iconName)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
}

extension MediaLibraryViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let type = sections[indexPath.section].items[indexPath.row]
        switch type {
        case .localFile:
            let vc = LocalFileBrowserViewController(directory: LocalFile.rootFile)
            navigationController?.pushViewController(vc, animated: true)
        case .smb:
            let vc = SMBLoginHistoryViewController()
            navigationController?.pushViewController(vc, animated: true)
        case .webdav:
            let vc = WebDavLoginHistoryViewController()
            navigationController?.pushViewController(vc, animated: true)
        case .ftp:
            let vc = FTPLoginHistoryViewController()
            navigationController?.pushViewController(vc, animated: true)
        case .emby:
            let vc = EmbyLoginHistoryViewController()
            navigationController?.pushViewController(vc, animated: true)
        case .jellyfin:
            let vc = JellyfinLoginHistoryViewController()
            navigationController?.pushViewController(vc, animated: true)
        case .pc:
            let vc = PCLoginHistoryViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
