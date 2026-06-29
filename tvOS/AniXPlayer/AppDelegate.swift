import UIKit
import AVFoundation
#if !os(tvOS)
import ANXLog
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Launcher.launch()

        ANX.logInfo(.player, "[App] Documents 路径: \(PathUtils.documentsURL.path)")

        // 配置音频会话，确保多声道/杜比全景声兼容
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
        } catch {
            ANX.logError(.player, "[App] AVAudioSession 配置失败: \(error)")
        }

        setupUI()

        // 恢复 iCloud 同步（如果之前已开启）
        if Preferences.shared.icloudSyncEnabled {
            Preferences.shared.store.startSync()
        }

        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = MainViewController()
        self.window?.makeKeyAndVisible()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showConflictAlert),
            name: .syncConflictDetected,
            object: nil
        )

        return true
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

    func applicationWillTerminate(_ application: UIApplication) {
        ANXLogHelper.close()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        ANXLogHelper.flush()
    }

    private func setupUI() {
        let tabbarAppearance = UITabBar.appearance()
        tabbarAppearance.barTintColor = .black

        let windowAppearance = UIWindow.appearance()
        windowAppearance.backgroundColor = .black

    }
}
