//
//  PlayerModalNavigationController.swift
//  AniXPlayer
//
//  播放器 modal 专用容器：外屏保持横屏；Duo 内屏会忽略方向锁，页面按宽度自适应。
//

import UIKit

class PlayerModalNavigationController: NavigationController {

    override var shouldAutorotate: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeLeft }

    @available(iOS 26.0, *)
    override var prefersInterfaceOrientationLocked: Bool { true }
}
