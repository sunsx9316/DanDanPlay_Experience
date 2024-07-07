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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.dataSource[indexPath.row]
        
        let cell = tableView.dequeueCell(class: PickFileTableViewCell.self, indexPath: indexPath)
        cell.titleLabel.text = type.name
        cell.iconImgView.image = UIImage(named: type.iconName)?.byTintColor(.mainColor)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let type = self.dataSource[indexPath.row]
        
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
        }
    }
    
}

extension MediaLibViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        let nvc = PlayerNavigationController(items: allFiles, selectedItem: didSelectFile)
        self.present(nvc, animated: true, completion: nil)
    }
    
}

class MediaLibViewController: ViewController {
    
    private enum CellType: CaseIterable {
        case localFile
        case smb
        case webDav
        case ftp
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
                return NSLocalizedString("电脑端", comment: "")
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
            }
            
        }
    }
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: PickFileTableViewCell.self)
        tableView.rowHeight = 50
        return tableView
    }()
    
    private lazy var dataSource = CellType.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("媒体库", comment: "")
        
        self.navigationItem.leftBarButtonItem = nil

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.setupNavigationItem()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.tableView.reloadData()
        self.setupNavigationItem()
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
    
    @objc private func onTouchSettingButton() {
        let vc = SettingViewController()
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func setupNavigationItem() {
        let commentItem = UIBarButtonItem(imageName: "Public/setting", target: self, action: #selector(onTouchSettingButton))
        self.navigationItem.rightBarButtonItem = commentItem
    }
}
