//
//  AppDelegate.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/1.
//

import UIKit
import Bugly

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        self.setup()
        
//        if #available(iOS 13.0, *) {
//
//        } else {
//            let vc = TabBarController()
        
        let vc = PickFileViewController()
        let nav = PickFileNavigationController(rootViewController: vc)
        nav.navigationBar.prefersLargeTitles = true
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = nav
        self.window?.makeKeyAndVisible()
//        }
        
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

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
    
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

    //MARK: - Private Method
    private func setup() {
        
        let isDevelop: Bool
        
        #if DEBUG
        isDevelop = true
        #else
        isDevelop = false
        #endif
        
        let config = BuglyConfig()
        config.channel = "AppStore"
        Bugly.start(withAppId: "a72dd7c16d", developmentDevice: isDevelop, config: config)
        
        do {
//            let navBarAppearance = UINavigationBar.appearance()

//            let backImage = UIImage(named: "Public/go_back")?.byTintColor(.navItemColor)?.withRenderingMode(.alwaysOriginal)
//            navBarAppearance.backIndicatorImage = backImage
//            navBarAppearance.backIndicatorTransitionMaskImage = backImage
            
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
        
        do {
            ANXLogHelper.setup()
        }
    }
}

