//
//  PCConnectSvrViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/2.
//

import UIKit

class PCConnectSvrViewController: BaseConnectSvrViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let rightBarButtonItem = UIBarButtonItem(imageName: "Public/add", target: self, action: #selector(onTouchAddButton))
        self.navigationItem.rightBarButtonItem = rightBarButtonItem
    }
    
    @objc private func onTouchAddButton() {
        let vc = PCQRScannerViewController()
        vc.scanSuccessCallBack = { [weak self] info in
            guard let self = self else { return }
            
            self.update(with: info)
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    

}
