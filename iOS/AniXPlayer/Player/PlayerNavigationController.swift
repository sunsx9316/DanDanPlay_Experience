//
//  PlayerNavigationController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/26.
//

import UIKit

class PlayerNavigationController: NavigationController {
    
    var playerViewController: PlayerViewController?
    
    init(items: [File], selectedItem: File? = nil) {
        let playerViewController = PlayerViewController(items: items, selectedItem: selectedItem)
        self.playerViewController = playerViewController
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .black

        if let playerViewController = self.playerViewController {
            self.setViewControllers([playerViewController], animated: false)
        }
    }

    override var shouldAutorotate: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeLeft }

    @available(iOS 26.0, *)
    override var prefersInterfaceOrientationLocked: Bool { true }
}
