//
//  FTPLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/30.
//

import UIKit

class FTPLoginHistoryViewController: BaseLoginHistoryViewController<FTPFile> {
    
    override var dataSource: [LoginInfo] {
        get {
            return Preferences.shared.ftpLoginInfos ?? []
        }
        
        set {
            Preferences.shared.ftpLoginInfos = newValue
        }
    }

}
