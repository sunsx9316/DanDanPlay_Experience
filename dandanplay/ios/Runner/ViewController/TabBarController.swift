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

        let vc = UIViewController()
        let nav = UINavigationController(rootViewController: vc)
        let img = UIImage(named: "Main/main_file")
        let item = UITabBarItem(title: "123", image: img, selectedImage: nil)
        nav.tabBarItem = item
    }
    


}
