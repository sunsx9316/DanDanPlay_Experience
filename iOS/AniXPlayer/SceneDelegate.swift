//
//  SceneDelegate.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/1.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        if url.isMediaFile || url.isSubtitleFile || url.isDanmakuFile {
            let fileName = url.lastPathComponent
            let toUrl = UIApplication.shared.documentsURL.appendingPathComponent(fileName)

            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                try FileManager.default.copyItem(at: url, to: toUrl)
                self.window?.showHUD(String(format: NSLocalizedString("导入 %@ 成功，请在\"本地文件\"中查看。", comment: ""), fileName))
            } catch let error {
                debugPrint(error)
                self.window?.showHUD(error.localizedDescription)
            }
        }
    }
}
