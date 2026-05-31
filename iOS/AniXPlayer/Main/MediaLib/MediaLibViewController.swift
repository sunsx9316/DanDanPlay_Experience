//
//  MediaLibViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/1.
//

import UIKit
import SnapKit
import YYCategories

extension MediaLibViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.sections[indexPath.section].items[indexPath.row]

        let cell = tableView.dequeueCell(class: PickFileTableViewCell.self, indexPath: indexPath)
        cell.titleLabel.text = type.name
        cell.iconImgView.image = UIImage(named: type.iconName)?.byTintColor(.mainColor)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let type = self.sections[indexPath.section].items[indexPath.row]

        switch type {
        case .localFile:
            let file = LocalFile.rootFile
            let vc = LocalFilesViewController(with: file, selectedFile: nil, filterType: .video)
            vc.delegate = self
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(vc, animated: true)
        case .smb:
            let vc = SMBLoginHistoryViewController()
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(vc, animated: true)
        case .webDav:
            let vc = WebDavLoginHistoryViewController()
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(vc, animated: true)
        case .ftp:
            let vc = FTPLoginHistoryViewController()
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(vc, animated: true)
        case .pc:
            let vc = PCLoginHistoryViewController()
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(vc, animated: true)
        case .emby:
            let vc = EmbyLoginHistoryViewController()
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(vc, animated: true)
        case .jellyfin:
            let vc = JellyfinLoginHistoryViewController()
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section].title
    }

}

extension MediaLibViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        let nvc = PlayerNavigationController(items: allFiles, selectedItem: didSelectFile)
        self.present(nvc, animated: true, completion: nil)
    }

}

class MediaLibViewController: ViewController {

    private enum CellType {
        case localFile
        case smb
        case webDav
        case ftp
        case emby
        case jellyfin
        case pc

        var name: String {
            switch self {
            case .localFile:
                return NSLocalizedString("本地文件", comment: "")
            case .smb:
                return NSLocalizedString("SMB", comment: "")
            case .webDav:
                return NSLocalizedString("WebDav", comment: "")
            case .ftp:
                return NSLocalizedString("FTP", comment: "")
            case .pc:
                return NSLocalizedString("弹弹play远程访问", comment: "")
            case .emby:
                return NSLocalizedString("Emby", comment: "")
            case .jellyfin:
                return NSLocalizedString("Jellyfin", comment: "")
            }
        }

        var iconName: String {
            switch self {
            case .localFile:
                return "PickFile/file"
            case .smb:
                return "PickFile/smb"
            case .webDav:
                return "PickFile/webdav"
            case .ftp:
                return "PickFile/ftp"
            case .pc:
                return "PickFile/computer"
            case .emby:
                return "PickFile/emby"
            case .jellyfin:
                return "PickFile/jellyfin"
            }

        }
    }

    private struct Section {
        let title: String
        let items: [CellType]
    }

    private lazy var sections: [Section] = [
        Section(title: NSLocalizedString("文件来源", comment: ""), items: [.localFile, .smb, .webDav, .ftp]),
        Section(title: NSLocalizedString("媒体服务器", comment: ""), items: [.emby, .jellyfin, .pc]),
    ]

    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerClassCell(class: PickFileTableViewCell.self)
        tableView.rowHeight = 50
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("媒体库", comment: "")

        self.navigationItem.leftBarButtonItem = nil

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }

    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.tableView.reloadData()
    }

    override var shouldAutorotate: Bool {
        return UIDevice.current.isPad
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.isPad {
            return .all
        }

        return .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

}
