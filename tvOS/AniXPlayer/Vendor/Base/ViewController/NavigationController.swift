//
//  NavigationController.swift
//  AniXPlayer
//
//  tvOS NavigationController 基类
//

import UIKit

class NavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
    }

    deinit {
        debugPrint("\(self) deinit")
    }
}
