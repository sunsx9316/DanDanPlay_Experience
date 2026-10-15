//
//  SceneDelegate.swift
//  AniXPlayer
//

import UIKit
import ANXLog

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainViewController()
        window.makeKeyAndVisible()
        self.window = window

        // 恢复 iCloud 同步（如果之前已开启）
        if Preferences.shared.icloudSyncEnabled {
            Preferences.shared.store.startSync()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showConflictAlert),
            name: .syncConflictDetected,
            object: nil
        )
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        ANXLogHelper.flush()
    }

    @objc private func showConflictAlert() {
        guard let rootVC = window?.rootViewController,
              case .conflict(let conflicts) = Preferences.shared.syncStatus else { return }

        let count = conflicts.count
        let message = String(format: NSLocalizedString("发现 %d 项设置与 iCloud 数据不一致，请选择以哪一端为准：", comment: ""), count)

        let alert = UIAlertController(
            title: NSLocalizedString("iCloud 同步冲突", comment: ""),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("使用本机数据", comment: ""),
            style: .default
        ) { _ in
            Preferences.shared.resolveConflicts(useCloud: false)
        })
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("使用 iCloud 数据", comment: ""),
            style: .default
        ) { _ in
            Preferences.shared.resolveConflicts(useCloud: true)
        })
        rootVC.present(alert, animated: true)
    }
}
