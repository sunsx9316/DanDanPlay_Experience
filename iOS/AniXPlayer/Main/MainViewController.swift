//
//  MainViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit
import SVGKit

class MainViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // 使用自定义的视图控制器
        let firstViewController = NavigationController(rootViewController: HomePageViewController())
        firstViewController.navigationBar.prefersLargeTitles = true
        if let svgImage = SVGKImage(named: "Home.svg") {
            svgImage.size = CGSize(width: 30, height: 30)
            firstViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("主页", comment: ""), image: svgImage.uiImage, selectedImage: nil)
        }
        
        
        let secondViewController = MediaLibNavigationController(rootViewController: MediaLibViewController())
        secondViewController.navigationBar.prefersLargeTitles = true
        if let svgImage = SVGKImage(named: "Media.svg") {
            svgImage.size = CGSize(width: 26, height: 26)
            secondViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("媒体库", comment: ""), image: svgImage.uiImage, selectedImage: nil)
        }
        
        let thirdViewController = NavigationController(rootViewController: UserInfoViewController())
        thirdViewController.navigationBar.prefersLargeTitles = true
        if let svgImage = SVGKImage(named: "User.svg") {
            svgImage.size = CGSize(width: 26, height: 26)
            thirdViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("用户", comment: ""), image: svgImage.uiImage, selectedImage: nil)
        }
        
        viewControllers = [firstViewController, secondViewController, thirdViewController]
        
        renewLoginInfo()
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
