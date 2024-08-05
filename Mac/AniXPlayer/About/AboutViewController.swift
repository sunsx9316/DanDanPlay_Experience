//
//  AboutViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/5.
//

import Cocoa
import RxSwift

class AboutViewController: ViewController {
    
    @IBOutlet weak var appIconImgView: NSImageView!
    
    @IBOutlet weak var appNameLabel: TextField!
    
    @IBOutlet weak var copyRightLabel: TextField!
    
    @IBOutlet weak var checkUpdateButton: NSButton!
    
    private lazy var appVersionModel = AppVersionModel()
    
    private lazy var updateInfo = BehaviorSubject<UpdateInfo?>(value: nil)
    
    private lazy var bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.appNameLabel.font = .ddp_small
        self.appNameLabel.textColor = .subtitleTextColor
        self.copyRightLabel.font = .ddp_small
        self.copyRightLabel.textColor = .subtitleTextColor
        
        self.appIconImgView.image = NSImage(named: "AppIcon")
        self.appNameLabel.text = AppInfoHelper.appDisplayName + " " + AppInfoHelper.appVersion
        self.copyRightLabel.text = AppInfoHelper.copyright
        
        self.title = NSLocalizedString("关于", comment: "") + AppInfoHelper.appDisplayName
        self.preferredContentSize = CGSize(width: 430, height: 240)
        
        self.updateInfo.subscribe(onNext: { [weak self] info in
            guard let self = self else { return }
            
            if let info = info, self.appVersionModel.shouldUpdate(updateInfo: info) {
                self.checkUpdateButton.title = NSLocalizedString("有新版本", comment: "")
            } else {
                self.checkUpdateButton.title = NSLocalizedString("检查更新", comment: "")
            }
        }).disposed(by: self.bag)
        
        checkUpdate(byUser: false)
    }
    
    @IBAction func onClickCheckUpdateButton(_ sender: NSButton) {
        checkUpdate(byUser: true)
    }
    
    private func showAppVersionVC(_ info: UpdateInfo) {
        let vc = AppVersionViewController(appVersiotn: info)
        vc.onClickCancelCallBack = { vc in
            vc.dismiss(nil)
        }
        
        vc.onClickOKCallBack = { vc in
            vc.dismiss(nil)
        }
        
        self.presentAsModalWindow(vc)
    }
    
    private func checkUpdate(byUser: Bool) {
        _ = self.appVersionModel.checkUpdate().subscribe(onNext: { [weak self] info in
            guard let self = self else { return }
            
            self.updateInfo.onNext(info)
            if self.appVersionModel.shouldUpdate(updateInfo: info) {
                self.showAppVersionVC(info)
            } else if byUser {
                let vc = NSAlert()
                vc.messageText = NSLocalizedString("提示", comment: "")
                vc.informativeText = NSLocalizedString("已是最新版本", comment: "")
                vc.alertStyle = .informational
                vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
                vc.runModal()
            }
        })
    }
}
