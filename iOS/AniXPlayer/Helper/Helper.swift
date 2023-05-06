//
//  Helper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import Foundation

class Helper {
    
    static let shared = Helper()
    
    weak var playerViewController: PlayerViewController?
    
    static var appDisplayName: String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    }
}
