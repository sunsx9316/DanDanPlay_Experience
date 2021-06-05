//
//  TabBarController.swift
//  Runner
//
//  Created by jimhuang on 2021/3/30.
//

import UIKit

class TabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        var vcs = [UIViewController]()
        
        do {
            let title = NSLocalizedString("文件", comment: "")
            let vc = PickFileViewController()
            vc.title = title
            let nav = UINavigationController(rootViewController: vc)
            let item = self.createTabBarItemWithImageName("Main/main_file", title: title)
            nav.tabBarItem = item
            vcs.append(nav)
        }
        
        self.tabBar.layer.shadowColor = UIColor.black.cgColor
        self.tabBar.layer.shadowRadius = 2
        self.tabBar.layer.shadowOpacity = 0.3
        self.tabBar.layer.shadowOffset = .zero
        self.viewControllers = vcs
    }
    
    override var shouldAutorotate: Bool {
        return UIDevice.current.isPad
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.isPad {
            return .all
        }
        
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    private func createTabBarItemWithImageName(_ imageName: String, title: String) -> UITabBarItem {
        let selectedImage = UIImage(named: imageName)?.byTintColor(.mainColor)?.withRenderingMode(.alwaysOriginal)
        let normalImage = UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal)
        let item = UITabBarItem(title: title, image: normalImage, selectedImage: selectedImage)
        item.setTitleTextAttributes([.font : UIFont.ddp_normal, .foregroundColor : UIColor.mainColor],
                                    for: .normal)
        return item
    }


}
