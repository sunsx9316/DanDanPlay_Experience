//
//  WebDavLoginHistoryViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/30.
//

import UIKit

class WebDavLoginHistoryViewController: BaseLoginHistoryViewController<WebDavFile> {

    override var dataSource: [LoginInfo] {
        get {
            return Preferences.shared.webDavLoginInfos ?? []
        }
        
        set {
            Preferences.shared.webDavLoginInfos = newValue
        }
    }

}
