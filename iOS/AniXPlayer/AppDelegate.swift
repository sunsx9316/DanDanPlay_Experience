//
//  AppDelegate.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/1.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        self.setup()
        
//        if #available(iOS 13.0, *) {
//
//        } else {
            let vc = TabBarController()
            self.window = UIWindow(frame: UIScreen.main.bounds)
            self.window?.rootViewController = vc
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

    //MARK: - Private Method
    private func setup() {
        do {
            let navBarAppearance = UINavigationBar.appearance()
            navBarAppearance.isTranslucent = false
            navBarAppearance.barTintColor = .mainColor
            navBarAppearance.titleTextAttributes = [.font : UIFont.systemFont(ofSize: 17, weight: .medium),
                                                    .foregroundColor : UIColor.navigationTitleColor]
            let backImage = UIImage(named: "Player/comment_back_item")?.withRenderingMode(.alwaysOriginal)
            navBarAppearance.backIndicatorImage = backImage
            navBarAppearance.backIndicatorTransitionMaskImage = backImage
            
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
        do {
            let placeholderAttributes: [NSAttributedString.Key : Any] = [.font : UIFont.ddp_normal, .foregroundColor : UIColor.placeholderColor]
            let attributedPlaceholder = NSAttributedString(string: "搜索", attributes: placeholderAttributes)
            UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).attributedPlaceholder = attributedPlaceholder
            let barButtonItemAppearance = UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
            barButtonItemAppearance.tintColor = UIColor.navigationTitleColor
            barButtonItemAppearance.title = "取消"
            barButtonItemAppearance.setTitleTextAttributes(placeholderAttributes, for: .normal)
        }
        
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

