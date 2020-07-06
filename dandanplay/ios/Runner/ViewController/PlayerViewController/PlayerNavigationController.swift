//
//  PlayerNavigationController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/26.
//

import UIKit

class PlayerNavigationController: UINavigationController {
    
    var playerViewController: PlayerViewController?
    
    init(urls: [URL]) {
        let playerViewController = PlayerViewController(urls: urls)
        self.playerViewController = playerViewController
        super.init(nibName: nil, bundle: nil)
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeviceOrientationDidChange), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override var shouldAutorotate: Bool {
        return visibleViewController?.shouldAutorotate ?? false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return visibleViewController?.supportedInterfaceOrientations ?? .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return visibleViewController?.preferredInterfaceOrientationForPresentation ?? .landscapeLeft
    }
    
    //MARK: Private
    @objc private func handleDeviceOrientationDidChange(_ notification: Notification) {
        guard let orientation = notification.userInfo?[UIApplication.statusBarFrameUserInfoKey] as? UIDeviceOrientation else { return }
        
        print("orientation = \(orientation)")
    }

}
