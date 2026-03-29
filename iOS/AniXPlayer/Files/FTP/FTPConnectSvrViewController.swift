//
//  FTPConnectSvrViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/3/29.
//

import UIKit

class FTPConnectSvrViewController: BaseConnectSvrViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addressLabel.addTarget(self, action: #selector(addressTextFieldDidBeginEditing), for: .editingDidBegin)
    }
    
    @objc private func addressTextFieldDidBeginEditing() {
        if self.addressLabel.text?.isEmpty == true {
            self.addressLabel.text = "ftp://"
        }
    }
}
