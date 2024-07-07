//
//  LocalFilesViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/14.
//

import UIKit

class LocalFilesViewController: FileBrowserViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        var items = [UIBarButtonItem]()
        items.append(.init(imageName: "Public/add", target: self, action: #selector(onTouchAddItem(_:))))
        
        if let addItem = self.navigationItem.rightBarButtonItem {
            items.append(addItem)
            self.navigationItem.rightBarButtonItem = nil
        }
        
        
        self.navigationItem.rightBarButtonItems = items
    }
    
    //MARK: Private Method
    @objc private func onTouchAddItem(_ item: UIBarButtonItem) {
        let vc = HttpServerViewController()
        self.navigationController?.pushViewController(vc, animated: true)
    }

}
