//
//  MainViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit
import YYCategories
import ANXLog

class MainViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // 使用自定义的视图控制器
        let firstViewController = NavigationController(rootViewController: HomePageViewController())
        firstViewController.navigationBar.prefersLargeTitles = true
        firstViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("主页", comment: ""), image: UIImage(named: "Home/Home")?.byResize(to: CGSize(width: 30, height: 30)), selectedImage: nil)


        let secondViewController = MediaLibNavigationController(rootViewController: MediaLibViewController())
        secondViewController.navigationBar.prefersLargeTitles = true
        secondViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("媒体库", comment: ""), image: UIImage(named: "Home/Media")?.byResize(to: CGSize(width: 26, height: 26)), selectedImage: nil)

        let thirdViewController = NavigationController(rootViewController: UserInfoViewController())
        thirdViewController.navigationBar.prefersLargeTitles = true
        thirdViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("我的", comment: ""), image: UIImage(named: "Home/User")?.byResize(to: CGSize(width: 26, height: 26)), selectedImage: nil)

        viewControllers = [firstViewController, secondViewController, thirdViewController]

        renewLoginInfo()
        updateSidebarPlacement()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: MainViewController, _) in
                self.updateSidebarPlacement()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if #available(iOS 17.0, *) { return }

        if previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass {
            updateSidebarPlacement()
        }
    }

    private func updateSidebarPlacement() {
        if #available(iOS 27.0, *) {
            let isRegularWidth = traitCollection.horizontalSizeClass == .regular
            mode = isRegularWidth ? .tabSidebar : .tabBar
            sidebar.preferredPlacement = isRegularWidth ? .sidebar : .automatic
        }
    }

    /// 刷新登录信息
    private func renewLoginInfo() {
        
        func renew() {
            UserNetworkHandle.renew { loginInfo, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.view.showError(error)
                    } else {
                        Preferences.shared.loginInfo = loginInfo
                    }
                }
            }
        }
        
        /// token 过期，请求新的token
        if let loginInfo = Preferences.shared.loginInfo {
            
            if let tokenExpireTime = loginInfo.tokenExpireTime {
                let date = Date()
                ANX.logInfo(.UI, "date:\(date) | JWT Token 过期时间：\(tokenExpireTime)")
                if date > tokenExpireTime {
                    renew()
                }
            } else {
                renew()
            }
        }
    }
    
}
