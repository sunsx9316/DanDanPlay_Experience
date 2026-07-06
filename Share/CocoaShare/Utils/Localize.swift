//
//  Localize.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/03/31.
//

import Foundation

class Localize {
        /// 切换应用语言
        /// - Parameter language: 目标语言
    static func setLanguage(_ language: AppLanguage) {
            // 1. 设置 AppleLanguages
        switch language {
        case .chinese:
            UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .followSystem:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }

        UserDefaults.standard.synchronize()

            // 2. 更新 Preferences
        Preferences.shared.appLanguage = language
    }
    
}
