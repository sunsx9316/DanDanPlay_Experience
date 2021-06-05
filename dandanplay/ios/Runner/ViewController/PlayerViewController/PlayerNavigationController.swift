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
    
    init(items: [File]) {
        let playerViewController = PlayerViewController(items: items)
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeviceOrientationDidChange), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
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
    
    //MARK: Private
    @objc private func handleDeviceOrientationDidChange(_ notification: Notification) {
        
        guard let orientationRawValue = notification.userInfo?[UIApplication.statusBarOrientationUserInfoKey] as? Int,
              let orientation = UIInterfaceOrientation(rawValue: orientationRawValue) else { return }
        
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            UserDefaults.standard.set(orientation.rawValue, forKey: defaultOrientationKey)
        default:
            break
        }
    }

}
