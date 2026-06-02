//
//  Launcher.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/8/12.
//

import Foundation
#if os(iOS)
import FirebaseCore
import FirebaseCrashlytics
#endif
#if !os(tvOS)
import ANXLog
#endif

/// 启动器，在app启动时会被调用
class Launcher {
    
    static func launch() {
        
        setupFirebase()
        
        setupLog()
        
        setupCache()
    }
    
    private static func setupFirebase() {
#if os(iOS)
#if os(macOS)
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
#endif
        FirebaseApp.configure()
#endif
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
    
}
