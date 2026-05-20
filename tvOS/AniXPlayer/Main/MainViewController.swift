import UIKit

class MainViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let homeVC = NavigationController(rootViewController: HomePageViewController())
        homeVC.tabBarItem = UITabBarItem(
            title: NSLocalizedString("主页", comment: ""),
            image: UIImage(systemName: "house"),
            tag: 0
        )

        let mediaLibVC = NavigationController(rootViewController: FileBrowserViewController())
        mediaLibVC.tabBarItem = UITabBarItem(
            title: NSLocalizedString("媒体库", comment: ""),
            image: UIImage(systemName: "folder"),
            tag: 1
        )

        let settingsVC = NavigationController(rootViewController: SettingViewController())
        settingsVC.tabBarItem = UITabBarItem(
            title: NSLocalizedString("设置", comment: ""),
            image: UIImage(systemName: "gear"),
            tag: 2
        )

        viewControllers = [homeVC, mediaLibVC, settingsVC]
    }
}
