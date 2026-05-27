//
//  PlayerSettingViewController.swift
//  AniXPlayer
//
//  tvOS 播放器设置 — UITabBarController 管理弹幕/媒体设置，对齐 iOS 实现
//

import UIKit
import SnapKit
import ANXLog

class PlayerSettingViewController: UITabBarController {

    // MARK: - Properties

    private let playerModel: PlayerModel

    // MARK: - Init

    init(playerModel: PlayerModel) {
        self.playerModel = playerModel
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("播放设置", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        let danmakuVC = DanmakuSettingViewController(playerModel: playerModel)
        danmakuVC.delegate = self
        danmakuVC.tabBarItem = UITabBarItem(
            title: NSLocalizedString("弹幕", comment: ""),
            image: UIImage(systemName: "text.bubble"),
            tag: 0
        )

        let mediaVC = MediaSettingViewController(playerModel: playerModel)
        mediaVC.delegate = self
        mediaVC.tabBarItem = UITabBarItem(
            title: NSLocalizedString("媒体", comment: ""),
            image: UIImage(systemName: "play.rectangle"),
            tag: 1
        )

        viewControllers = [danmakuVC, mediaVC]
    }
}

// MARK: - DanmakuSettingViewControllerDelegate

extension PlayerSettingViewController: DanmakuSettingViewControllerDelegate {
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        ANX.logInfo(.player, "[PlayerSetting] 加载本地弹幕")
        let fileBrowserVC = FileBrowserViewController(directory: LocalFile.rootFile)
        fileBrowserVC.filterType = .danmaku
        fileBrowserVC.delegate = self
        navigationController?.pushViewController(fileBrowserVC, animated: true)
    }

    func searchDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        ANX.logInfo(.player, "[PlayerSetting] 搜索弹幕")
        guard let media = playerModel.mediaModel.media else { return }
        let matchVC = MatchsViewController(file: media, playerModel: playerModel)
        navigationController?.pushViewController(matchVC, animated: true)
    }

    func filterDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        ANX.logInfo(.player, "[PlayerSetting] 弹幕过滤")
        let filterVC = FilterDanmakuViewController(danmakuModel: playerModel.danmakuModel)
        navigationController?.pushViewController(filterVC, animated: true)
    }

    func showDanmakuListInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        ANX.logInfo(.player, "[PlayerSetting] 显示弹幕列表")
        let danmakuListVC = DanmakuListViewController(danmakuModel: playerModel.danmakuModel)
        navigationController?.pushViewController(danmakuListVC, animated: true)
    }
}

// MARK: - MediaSettingViewControllerDelegate

extension PlayerSettingViewController: MediaSettingViewControllerDelegate {
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController) {
        ANX.logInfo(.player, "[PlayerSetting] 加载字幕")
        let fileBrowserVC = FileBrowserViewController(directory: LocalFile.rootFile)
        fileBrowserVC.filterType = .subtitle
        fileBrowserVC.delegate = self
        navigationController?.pushViewController(fileBrowserVC, animated: true)
    }

    func changeSubtitleFontInMediaSettingViewController(_ vc: MediaSettingViewController) {
        ANX.logInfo(.player, "[PlayerSetting] 字幕字体设置")
        // TODO: 字幕字体设置
    }
}

// MARK: - FileBrowserViewControllerDelegate

extension PlayerSettingViewController: FileBrowserViewControllerDelegate {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile file: File, allFiles: [File]) {
        navigationController?.popViewController(animated: false)
        if vc.filterType == .danmaku {
            _ = playerModel.danmakuModel.loadDanmakuByUser(file).subscribe()
        } else if vc.filterType == .subtitle {
            _ = playerModel.mediaModel.loadSubtitleByUser(file).subscribe()
        }
    }
}