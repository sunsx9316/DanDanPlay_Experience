//
//  NavigationController.swift
//  Runner
//
//  Created by jimhuang on 2021/3/7.
//

import UIKit

class NavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .backgroundColor
        self.setupNavigationItem()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        self.setupNavigationItem()
    }
    
    private func setupNavigationItem() {
        let backImage = UIImage(named: "Public/go_back")?.byTintColor(.navItemColor)?.withRenderingMode(.alwaysOriginal)
        self.navigationBar.backIndicatorImage = backImage
        self.navigationBar.backIndicatorTransitionMaskImage = backImage
    }
}
