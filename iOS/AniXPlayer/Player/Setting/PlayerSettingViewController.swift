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
                return NSLocalizedString("弹幕", comment: "")
            case .mediaSetting:
                return NSLocalizedString("媒体", comment: "")
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
    
    private lazy var vcs: [UIViewController] = {
        var vcs = [UIViewController]()
        
        for type in VCType.allCases {
            switch type {
            case .danmakuSetting:
                let vc = DanmakuSettingViewController(playerModel: self.playerModel)
                vc.delegate = self.delegate
                vcs.append(vc)
            case .mediaSetting:
                let vc = MediaSettingViewController(playerModel: self.playerModel)
                vc.delegate = self.delegate
                vcs.append(vc)
            }
        }
        
        return vcs
    }()
    
    private var currentVC: UIViewController?
    
    private lazy var blurVuew: UIVisualEffectView = {
        let blurVuew = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        return blurVuew
    }()
    
    private var playerModel: PlayerModel!
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeLeft
    }
    
    weak var delegate: (DanmakuSettingViewControllerDelegate & MediaSettingViewControllerDelegate)?
    
    init(playerModel: PlayerModel) {
        self.playerModel = playerModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            self.view.addSubview(selectedVC.view)
            selectedVC.view.snp.makeConstraints { (make) in
                make.top.equalTo(self.segmentedControl.snp.bottom).offset(10)
                make.leading.trailing.bottom.equalToSuperview()
            }
            self.currentVC = selectedVC
        }
    }

}
