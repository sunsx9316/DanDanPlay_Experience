//
//  ViewController.swift
//  AniXPlayer
//
//  tvOS ViewController 基类 — 焦点环境配置
//

import UIKit

class ViewController: UIViewController {

    /// 子类可设置此属性来指定页面首次加载时的默认焦点视图
    var defaultFocusView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let view = defaultFocusView {
            return [view]
        }
        return super.preferredFocusEnvironments
    }

    deinit {
        debugPrint("\(self) deinit")
    }
}
