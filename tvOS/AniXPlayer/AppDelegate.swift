import UIKit
#if !os(tvOS)
import ANXLog
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Launcher.launch()

        ANX.logInfo(.player, "[App] Documents 路径: \(PathUtils.documentsURL.path)")

        setupUI()

        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = MainViewController()
        self.window?.makeKeyAndVisible()

        return true
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
