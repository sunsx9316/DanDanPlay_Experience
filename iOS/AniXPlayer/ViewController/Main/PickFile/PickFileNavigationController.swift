//
//  PickFileNavigationController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/18.
//

import UIKit

class PickFileNavigationController: NavigationController {

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

}
