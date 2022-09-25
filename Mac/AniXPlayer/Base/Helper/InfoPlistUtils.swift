//
//  InfoPlistUtils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/17.
//

import Foundation

class InfoPlistUtils {
    static var appName: String {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "AniXPlayer"
    }
}
