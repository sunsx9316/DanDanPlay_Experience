//
//  MediaLibraryViewController.swift
//  AniXPlayer
//
//  tvOS 媒体库 — 文件来源列表
//

import UIKit

class MediaLibraryViewController: ViewController {

    private enum Source: Int, CaseIterable {
        case local
        case smb
        case webdav
        case ftp
        case pc

        var title: String {
            switch self {
            case .local: return NSLocalizedString("本地文件", comment: "")
            case .smb: return NSLocalizedString("SMB", comment: "")
            case .webdav: return NSLocalizedString("WebDAV", comment: "")
            case .ftp: return NSLocalizedString("FTP", comment: "")
            case .pc: return NSLocalizedString("电脑端", comment: "")
            }
        }

        var iconName: String {
            switch self {
            case .local: return "internaldrive"
            case .smb: return "network"
            case .webdav: return "globe"
            case .ftp: return "externaldrive.connected.to.line.below"
            case .pc: return "desktopcomputer"
            }
        }
    }

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(FileListCell.self, forCellReuseIdentifier: FileListCell.reuseIdentifier)
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Source.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileListCell.reuseIdentifier, for: indexPath) as! FileListCell
        let source = Source(rawValue: indexPath.row)!
        cell.configureAsSource(title: source.title, iconName: source.iconName)
        return cell
    }
}

extension MediaLibraryViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let source = Source(rawValue: indexPath.row)!
        switch source {
        case .local:
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
        case .pc:
            let vc = PCLoginHistoryViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
