//
//  AppDelegate.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/1.
//

import UIKit
import ANXLog
import ANXLog_Objc

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        Launcher.launch()
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = MainViewController()
        self.window?.makeKeyAndVisible()
        
        return true
    }

    // MARK: UISceneSession Lifecycle

//    @available(iOS 13.0, *)
//    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
//
//        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
//        config.delegateClass = SceneDelegate.self
//        return config
//    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        if url.isMediaFile || url.isSubtitleFile || url.isDanmakuFile {
            let fileName = url.lastPathComponent
            let toUrl = UIApplication.shared.documentsURL.appendingPathComponent(fileName)
            do {
                try FileManager.default.copyItem(at: url, to: toUrl)
                app.keyWindow?.showHUD(String(format: NSLocalizedString("导入 %@ 成功，请在“本地文件”中查看。", comment: ""), fileName))
            } catch let error {
                debugPrint(error)
            }
        }
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        ANXLogHelper.close()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        ANXLogHelper.flush()
    }
    
}

