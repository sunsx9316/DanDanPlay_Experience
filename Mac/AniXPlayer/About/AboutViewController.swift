//
//  AboutViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/5.
//

import Cocoa
import SnapKit
import RxSwift

class AboutViewController: ViewController {

    private lazy var appIconImgView: ImageView = {
        let imgView = ImageView()
        imgView.image = NSImage(named: "AppIcon")
        imgView.setScaling(.scaleToFill)
        return imgView
    }()

    private lazy var appNameLabel: Label = {
        let label = Label()
        label.font = .ddp_small
        label.textColor = .subtitleTextColor
        return label
    }()

    private lazy var copyRightLabel: Label = {
        let label = Label()
        label.font = .ddp_small
        label.textColor = .subtitleTextColor
        return label
    }()

    private lazy var checkUpdateButton: NSButton = {
        let button = NSButton()
        button.title = NSLocalizedString("检查更新", comment: "")
        button.bezelStyle = .rounded
        button.addTarget(self, action: #selector(onClickCheckUpdateButton))
        return button
    }()

    private lazy var appVersionModel = AppVersionModel()

    private lazy var updateInfo = BehaviorSubject<UpdateInfo?>(value: nil)

    private lazy var bag = DisposeBag()

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 430, height: 240))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.appIconImgView)
        self.view.addSubview(self.appNameLabel)
        self.view.addSubview(self.copyRightLabel)
        self.view.addSubview(self.checkUpdateButton)

        self.appIconImgView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(80)
        }
        self.appNameLabel.snp.makeConstraints { make in
            make.top.equalTo(self.appIconImgView.snp.bottom).offset(45)
            make.centerX.equalTo(self.appIconImgView)
        }
        self.copyRightLabel.snp.makeConstraints { make in
            make.top.equalTo(self.appNameLabel.snp.bottom).offset(10)
            make.centerX.equalTo(self.appNameLabel)
        }
        self.checkUpdateButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-10)
            make.centerX.equalTo(self.copyRightLabel)
        }

        self.appNameLabel.text = AppInfoHelper.appDisplayName + " " + AppInfoHelper.appVersion
        self.copyRightLabel.text = AppInfoHelper.copyright

        self.title = NSLocalizedString("关于", comment: "") + AppInfoHelper.appDisplayName

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

    @objc private func onClickCheckUpdateButton(_ sender: NSButton) {
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

            if let info = info {
                self.updateInfo.onNext(info)
                if self.appVersionModel.shouldUpdate(updateInfo: info) {
                    self.showAppVersionVC(info)
                } else if byUser {
                    self.showAlreadyLatestAlert()
                }
            } else if byUser {
                self.showAlreadyLatestAlert()
            }
        }, onError: { [weak self] _ in
            guard let self = self, byUser else { return }
            let vc = NSAlert()
            vc.messageText = NSLocalizedString("提示", comment: "")
            vc.informativeText = NSLocalizedString("检查更新失败", comment: "")
            vc.alertStyle = .warning
            vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
            vc.runModal()
        })
    }

    private func showAlreadyLatestAlert() {
        let vc = NSAlert()
        vc.messageText = NSLocalizedString("提示", comment: "")
        vc.informativeText = NSLocalizedString("已是最新版本", comment: "")
        vc.alertStyle = .informational
        vc.addButton(withTitle: NSLocalizedString("确定", comment: ""))
        vc.runModal()
    }
}
