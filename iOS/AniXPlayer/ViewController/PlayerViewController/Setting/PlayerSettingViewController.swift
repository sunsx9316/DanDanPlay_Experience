//
//  PlayerSettingViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/20.
//

import UIKit
import SnapKit

class PlayerSettingViewController: ViewController {
    
    private enum VCType: String, CaseIterable {
        case danmakuSetting
        case mediaSetting
        
        var title: String {
            switch self {
            case .danmakuSetting:
                return NSLocalizedString("弹幕设置", comment: "")
            case .mediaSetting:
                return NSLocalizedString("播放器设置", comment: "")
            }
        }
        
        var vc: UIViewController {
            switch self {
            case .danmakuSetting:
                return DanmakuSettingViewController()
            case .mediaSetting:
                return MediaSettingViewController()
            }
        }
        
    }
    
    private lazy var segmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl(items: VCType.allCases.compactMap({ $0.title }))
        segmentedControl.tintColor = .mainColor
        segmentedControl.addTarget(self, action: #selector(onTouchSegmentedControl(_:)), for: .valueChanged)
        segmentedControl.setTitleTextAttributes([.foregroundColor : UIColor.lightGray], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor : UIColor.black], for: .selected)
        return segmentedControl
    }()
    
    private lazy var vcs = VCType.allCases.compactMap({ $0.vc })
    
    private var currentVC: UIViewController?
    
    private lazy var blurVuew: UIVisualEffectView = {
        let blurVuew = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        return blurVuew
    }()
    
    weak var delegate: (DanmakuSettingViewControllerDelegate & MediaSettingViewControllerDelegate)?
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeLeft
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .clear
        
        self.view.addSubview(self.blurVuew)
        
        for vc in vcs {
            self.addChild(vc)
        }
        
        self.view.addSubview(self.segmentedControl)
        
        self.blurVuew.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.segmentedControl.snp.makeConstraints { (make) in
            make.top.equalTo(10)
            make.centerX.equalToSuperview()
        }
        
        self.segmentedControl.selectedSegmentIndex = 0
        self.selectedIndex(0)
    }
    

    //MARK: Private Method
    @objc private func onTouchSegmentedControl(_ segmentedControl: UISegmentedControl) {
        let index = segmentedControl.selectedSegmentIndex
        self.selectedIndex(index)
    }
    
    private func selectedIndex(_ index: Int) {
        if index < self.vcs.count {
            self.currentVC?.view.removeFromSuperview()
            
            let selectedVC = self.vcs[index]
            
            if let selectedVC = selectedVC as? DanmakuSettingViewController {
                selectedVC.delegate = self.delegate
            } else if let selectedVC = selectedVC as? MediaSettingViewController {
                selectedVC.delegate = self.delegate
            }
            
            self.view.addSubview(selectedVC.view)
            selectedVC.view.snp.makeConstraints { (make) in
                make.top.equalTo(self.segmentedControl.snp.bottom).offset(10)
                make.leading.trailing.bottom.equalToSuperview()
            }
            self.currentVC = selectedVC
        }
    }

}
