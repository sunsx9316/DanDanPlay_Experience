//
//  AppInfoHelper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/20.
//

import Foundation

class AppInfoHelper {

    /// CFBundleDisplayName，fallback 到 CFBundleName
    static var appDisplayName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ""
    }

    static var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static var buildNumber: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    static var appIconName: String? {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let lastIcon = files.last else { return nil }
        return lastIcon
    }

    static var copyright: String {
        let year = Calendar.current.component(.year, from: Date())
        return "Copyright © 2022 - \(year) jimhuang"
    }

}

