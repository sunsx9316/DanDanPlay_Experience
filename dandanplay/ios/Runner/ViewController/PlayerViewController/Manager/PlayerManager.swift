//
//  PlayerManager.swift
//  Runner
//
//  Created by JimHuang on 2020/7/27.
//

import UIKit

private var FileBrowerManagerTransitioningKey = 0

protocol PlayerManagerDelegate: class {
    func didSelectedURLs(urls: [URL])
    func didSelectedDanmakuURLs(urls: [URL])
}

extension PlayerManagerDelegate {
    func didSelectedURLs(urls: [URL]) {}
    func didSelectedDanmakuURLs(urls: [URL]) {}
}

class PlayerManager {
    
    private weak var danmakuBrower: FilesViewController?
    
    private weak var settingViewController: PlayerSettingViewController?
    
    private weak var videoFilesVC: UIViewController?
    
    weak var delegate: PlayerManagerDelegate?
    

    
    func showCustomDanmakuBrower(from: UIViewController, file: File) {
        let vc = FilesViewController(with: file, filterType: .danmaku)
        let animater = PlayerControlAnimater()
        objc_setAssociatedObject(vc, &FileBrowerManagerTransitioningKey, animater, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = animater
        self.danmakuBrower = vc
        
        from.present(vc, animated: true, completion: nil)
    }
    
    func showFileBrower(from: UIViewController, file: File) {
        let vc = FilesViewController(with: file, filterType: .video)
        let nav = UINavigationController(rootViewController: vc)
        let animater = PlayerControlAnimater()
        objc_setAssociatedObject(vc, &FileBrowerManagerTransitioningKey, animater, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        nav.modalPresentationStyle = .custom
        nav.transitioningDelegate = animater
        self.videoFilesVC = nav
        from.present(nav, animated: true, completion: nil)
    }
    
    func showSetting(from: UIViewController) {
        let vc = PlayerSettingViewController(project: nil, nibName: nil, bundle: nil)
        let animater = PlayerControlAnimater()
        objc_setAssociatedObject(vc, &FileBrowerManagerTransitioningKey, animater, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = animater
        self.settingViewController = vc
        from.present(vc, animated: true, completion: nil)
    }
    
}

extension PlayerManager: FileBrowerManagerDelegate {
    func didSelectedPaths(manager: FileBrowerManager, urls: [URL]) {
        if manager == self.danmakuBrower {
            delegate?.didSelectedDanmakuURLs(urls: urls)
        }
    }
}

//extension PlayerManager: FilesViewControllerDelegate {
//    func filesViewController(_ vc: FilesViewController, didSelectFile: File) {
//        delegate?.didSelectedURLs(urls: [didSelectFile.url])
//    }
//    
//}
