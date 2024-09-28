//
//  AppInfoHelper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/20.
//

import Foundation

class AppInfoHelper {
    
    static var appDisplayName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
    }
    
    static var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
    
    static var copyright: String {
        return Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }
    
}

