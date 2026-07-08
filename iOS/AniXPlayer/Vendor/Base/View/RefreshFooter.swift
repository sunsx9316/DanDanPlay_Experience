//
//  RefreshFooter.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/8.
//

import UIKit
import MJRefresh

class RefreshFooter: MJRefreshAutoNormalFooter {

    override func prepare() {
        super.prepare()
        setupInit()
    }

    private func setupInit() {
        self.stateLabel?.font = .ddp_normal
        self.setTitle("", for: .idle)
        self.setTitle(NSLocalizedString("正在加载...", comment: ""), for: .refreshing)
        self.setTitle(NSLocalizedString("没有更多了", comment: ""), for: .noMoreData)
        self.isAutomaticallyChangeAlpha = true
        self.triggerAutomaticallyRefreshPercent = 0.5
    }
}
