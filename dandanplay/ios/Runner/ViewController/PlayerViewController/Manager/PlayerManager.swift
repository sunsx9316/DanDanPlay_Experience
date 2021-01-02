//
//  PlayerManager.swift
//  Runner
//
//  Created by JimHuang on 2020/7/27.
//

import UIKit
import dandanplayfilepicker

private var FileBrowerManagerTransitioningKey = 0

protocol PlayerManagerDelegate: class {
    func didSelectedURLs(urls: [URL])
}

extension PlayerManagerDelegate {
    func didSelectedURLs(urls: [URL]) {}
}

class PlayerManager {
    private lazy var fileBrower: FileBrowerManager = {
        let manager = FileBrowerManager(multipleSelection: false)
        manager.delegate = self
        self.fileBrower = manager
        let animater = PlayerControlAnimater()
        objc_setAssociatedObject(manager, &FileBrowerManagerTransitioningKey, animater, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        manager.containerViewController.modalPresentationStyle = .custom
        manager.containerViewController.transitioningDelegate = animater
        return manager
    }()
    
    private lazy var settingViewController: PlayerSettingViewController = {
        let vc = PlayerSettingViewController(project: nil, nibName: nil, bundle: nil)
        let extractedExpr = PlayerControlAnimater()
        let animater = extractedExpr
        objc_setAssociatedObject(vc, &FileBrowerManagerTransitioningKey, animater, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = animater
        return vc
    }()
    
    weak var delegate: PlayerManagerDelegate?
    
    func showFileBrower(from: UIViewController) {
        from.present(self.fileBrower.containerViewController, animated: true, completion: nil)
    }
    
    func dismissFileBrower() {
        self.fileBrower.containerViewController.dismiss(animated: true, completion: nil)
    }
    
    func showSetting(from: UIViewController) {
        from.present(self.settingViewController, animated: true, completion: nil)
    }
    
    func dismissSetting() {
        self.settingViewController.dismiss(animated: true, completion: nil)
    }
}

extension PlayerManager: FileBrowerManagerDelegate {
    func didSelectedPaths(manager: FileBrowerManager, paths: [String]) {
        let urls = paths.compactMap({ URL(fileURLWithPath: $0) })
        delegate?.didSelectedURLs(urls: urls)
    }
}
