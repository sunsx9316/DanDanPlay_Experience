//
//  PlayerNavigationController.swift
//  Runner
//
//  Created by JimHuang on 2020/5/26.
//

import UIKit

class PlayerNavigationController: UINavigationController {
    
    var playerViewController: PlayerViewController?
    
    private let defaultOrientationKey = "PlayerDefaultOrientationKey";
    
    init(urls: [URL]) {
        let playerViewController = PlayerViewController(urls: urls)
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        let rawValue = UserDefaults.standard.integer(forKey: defaultOrientationKey)
        guard let orientation = UIInterfaceOrientation(rawValue: rawValue),
              (orientation == .landscapeLeft || orientation == .landscapeRight) else { return .landscapeLeft }
        
        return orientation
    }
    
    //MARK: Private
    @objc private func handleDeviceOrientationDidChange(_ notification: Notification) {
        guard let orientation = notification.userInfo?[UIApplication.statusBarFrameUserInfoKey] as? UIDeviceOrientation else { return }
        
        let saveOrientation: UIInterfaceOrientation
        switch orientation {
        case .landscapeLeft:
            saveOrientation = .landscapeLeft
        case .landscapeRight:
            saveOrientation = .landscapeRight
        default:
            saveOrientation = .landscapeLeft
        }
        
        UserDefaults.standard.set(saveOrientation.rawValue, forKey: defaultOrientationKey)
    }

}
