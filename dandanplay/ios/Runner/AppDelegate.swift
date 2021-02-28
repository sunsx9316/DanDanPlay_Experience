import UIKit
import Flutter
import DDPMediaPlayer

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    lazy var engine: FlutterEngine = {
        return FlutterEngine(name: "App main engine")
    }()
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let flag = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        self.engine.run()
        let vc = MainViewController(engine: self.engine, nibName: nil, bundle: nil)
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window.rootViewController = vc
        self.window.makeKeyAndVisible()
        
        return flag
    }
    
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return true
    }
    
    override func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
}
