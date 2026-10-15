import UIKit
import AVFoundation
import ANXLog

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

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

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        ANXLogHelper.close()
    }

    private func setupUI() {
        let tabbarAppearance = UITabBar.appearance()
        tabbarAppearance.barTintColor = .black

        let windowAppearance = UIWindow.appearance()
        windowAppearance.backgroundColor = .black

    }
}
