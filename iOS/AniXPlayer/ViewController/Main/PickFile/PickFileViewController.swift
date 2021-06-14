//
//  PickFileViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/1.
//

import UIKit
import SnapKit
import YYCategories

extension PickFileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.dataSource[indexPath.row]
        
        let cell = tableView.dequeueCell(class: PickFileTableViewCell.self, indexPath: indexPath)
        cell.titleLabel.text = type.name
        cell.iconImgView.image = UIImage(named: type.iconName)
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
        }
    }
    
}

extension PickFileViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        let nvc = PlayerNavigationController(items: allFiles, selectedItem: didSelectFile)
        self.present(nvc, animated: true, completion: nil)
    }
    
}

class PickFileViewController: ViewController {
    
    private enum CellType: CaseIterable {
        case localFile
        case smb
        case webDav
        case ftp
        
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
            }
        }
        
        var iconName: String {
            switch self {
            case .localFile:
                return "File/file_phone"
            case .smb:
                return "File/file_net_equipment"
            case .webDav:
                return "File/file_web_dav"
            case .ftp:
                return "File/file_ftp"
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
        
        self.navigationItem.leftBarButtonItem = nil

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.addNavigationItem()
    }
    
    private func addNavigationItem() {
        let commentItem = UIBarButtonItem(imageName: "Comment/comment_setting", target: self, action: #selector(onTouchSettingButton))
        self.navigationItem.rightBarButtonItem = commentItem
    }
    
    @objc private func onTouchSettingButton() {
        let vc = SettingViewController()
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
    

}
