//
//  Launcher.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/8/12.
//

import Foundation
import FirebaseCore
import FirebaseCrashlytics
import ANXLog
import ANXLog_Objc

/// 启动器，在app启动时会被调用
class Launcher {
    
    static func launch() {
        
        setupFirebase()
        
        setupLog()
        
        setupUI()
        
        setupCache()
    }
    
    private static func setupFirebase() {
        FirebaseApp.configure()
    }
    
    private static func setupLog() {
        ANXLogHelper.setup()
    }
    
    private static func setupCache() {
        if !FileManager.default.fileExists(atPath: PathUtils.cacheURL.path) {
            do {
                try FileManager.default.createDirectory(at: PathUtils.cacheURL, withIntermediateDirectories: true)
            } catch {
                debugPrint("cache路径创建出错 \(error)")
            }
        }
    }
    
    
    private static func setupUI() {
        do {
            let barButtonAppearance = UIBarButtonItem.appearance()
            barButtonAppearance.setBackButtonTitlePositionAdjustment(UIOffset(horizontal: 0, vertical: -5), for: .default)
        }
        
        do {
            let tabbarAppearance = UITabBar.appearance()
            tabbarAppearance.barTintColor = .backgroundColor
        }
        
        do {
            let windowAppearance = UIWindow.appearance()
            windowAppearance.backgroundColor = .backgroundColor
        }
        
        //搜索框
//        do {
//            let placeholderAttributes: [NSAttributedString.Key : Any] = [.font : UIFont.ddp_normal, .foregroundColor : UIColor.placeholderColor]
//            let barButtonItemAppearance = UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
//            barButtonItemAppearance.tintColor = UIColor.navigationTitleColor
//            barButtonItemAppearance.title = "取消"
//            barButtonItemAppearance.setTitleTextAttributes(placeholderAttributes, for: .normal)
//        }
        
        // 滚动条
        do {
            let sliderAppearance = UISlider.appearance()
            sliderAppearance.tintColor = .mainColor
        }
        
        // 开关
        
        do {
            let switchAppearance = UISwitch.appearance()
            switchAppearance.onTintColor = .mainColor
        }
        
        do {
            let tableView = UITableView.appearance()
            tableView.separatorColor = .separatorColor
        }
    }
    
}
