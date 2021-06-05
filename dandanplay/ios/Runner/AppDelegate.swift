import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
    
//    lazy var engine: FlutterEngine = {
//        return FlutterEngine(name: "App main engine")
//    }()
    
    var window: UIWindow?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
//        let flag = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
//        self.engine.run()
//        let vc = MainViewController(engine: self.engine, nibName: nil, bundle: nil)
//        self.window = UIWindow(frame: UIScreen.main.bounds)
//        self.window.rootViewController = vc
//        self.window.makeKeyAndVisible()
        
        if #available(iOS 13.0, *) {
            
        } else {
            let vc = TabBarController()
            self.window = UIWindow(frame: UIScreen.main.bounds)
            self.window?.rootViewController = vc
            self.window?.makeKeyAndVisible()            
        }
        
        self.setup()
        
        return true
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.sceneClass = SceneDelegate.self
        return configuration
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
    
    
    private func setup() {
        let navBarAppearance = UINavigationBar.appearance()
        navBarAppearance.isTranslucent = false
        navBarAppearance.barTintColor = .mainColor
        navBarAppearance.titleTextAttributes = [.font : UIFont.systemFont(ofSize: 17, weight: .medium),
                                             .foregroundColor : UIColor.white]
        
        let backImage = UIImage(named: "Player/comment_back_item")?.withRenderingMode(.alwaysOriginal)
        navBarAppearance.backIndicatorImage = backImage
        navBarAppearance.backIndicatorTransitionMaskImage = backImage
        
        let barButtonAppearance = UIBarButtonItem.appearance()
        barButtonAppearance.setBackButtonTitlePositionAdjustment(UIOffset(horizontal: 0, vertical: -5), for: .default)
        
        let tabbarAppearance = UITabBar.appearance()
        tabbarAppearance.barTintColor = .mainColor
        
    }
}
