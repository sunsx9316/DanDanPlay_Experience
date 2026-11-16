//
//  WelcomeTrendingPageViewController.swift
//  AniXPlayer
//
//  macOS：欢迎页排行榜页，内嵌现有 TrendingViewController。
//

import Cocoa
import SnapKit

final class WelcomeTrendingPageViewController: ViewController, WelcomeShellLoginAware {

    weak var router: WelcomeShellRouting?

    private let trendingVC = TrendingViewController()

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 620))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("排行榜", comment: "")

        let header = WelcomeShellPageHeaderView(
            title: NSLocalizedString("排行榜", comment: ""),
            subtitle: NSLocalizedString("全站热播、飙升与新番排行", comment: "")
        )

        trendingVC.onSelectAnime = { [weak self] animeId in
            self?.router?.openDetail(animeId: animeId)
        }

        addChild(trendingVC)
        view.addSubview(header)
        view.addSubview(trendingVC.view)

        header.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(22)
        }
        trendingVC.view.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func welcomeShellLoginStateDidChange() {
        trendingVC.refreshAfterLoginStateChange()
    }
}
