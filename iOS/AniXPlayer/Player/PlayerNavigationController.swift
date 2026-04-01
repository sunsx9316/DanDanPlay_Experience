//
//  PlayerNavigationController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/26.
//

import UIKit

class PlayerNavigationController: NavigationController {
    
    var playerViewController: PlayerViewController?
    
    private let defaultOrientationKey = "PlayerDefaultOrientationKey";
    
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            if size.width > size.height {
                    // 横屏布局：隐藏状态栏、全屏播放器
                    // 获取当前的界面方向
                if let windowScene = self.view.window?.windowScene {
                    let orientation = windowScene.interfaceOrientation
                    UserDefaults.standard.set(orientation.rawValue, forKey: self.defaultOrientationKey)
                }
            }
        }
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.landscapeRight, .landscapeLeft]
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        let rawValue = UserDefaults.standard.integer(forKey: defaultOrientationKey)
        guard let orientation = UIInterfaceOrientation(rawValue: rawValue),
              (orientation == .landscapeLeft || orientation == .landscapeRight) else { return .landscapeLeft }
        
        return orientation
    }

}
