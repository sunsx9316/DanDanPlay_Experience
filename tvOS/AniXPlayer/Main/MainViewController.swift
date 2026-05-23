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

        let mediaLibVC = NavigationController(rootViewController: MediaLibraryViewController())
        mediaLibVC.tabBarItem = UITabBarItem(
            title: NSLocalizedString("媒体库", comment: ""),
            image: UIImage(systemName: "folder"),
            tag: 1
        )

        let userVC = NavigationController(rootViewController: UserInfoViewController())
        userVC.tabBarItem = UITabBarItem(
            title: NSLocalizedString("我的", comment: ""),
            image: UIImage(systemName: "person"),
            tag: 2
        )

        viewControllers = [homeVC, mediaLibVC, userVC]
    }
}
