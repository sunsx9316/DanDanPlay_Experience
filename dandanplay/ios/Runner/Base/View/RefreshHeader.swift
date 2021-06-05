//
//  RefreshHeader.swift
//  Runner
//
//  Created by jimhuang on 2021/3/29.
//

import UIKit
import MJRefresh

class RefreshHeader: MJRefreshNormalHeader {
    
    private lazy var refreshTexts: [String] = {
        if let path = Bundle.main.path(forResource: "RefreshText", ofType: "plist"), let arr = NSArray(contentsOfFile: path) as? [String] {
            return arr
        }
        return []
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    override var state: MJRefreshState {
        didSet {
            if self.state == .refreshing {
                self.labelLeftInset = 20
                self.setTitle(self.refreshTexts.randomElement()!, for: .refreshing)
                self.loadingView?.isHidden = true
            } else {
                self.labelLeftInset = 0
                self.loadingView?.isHidden = false
            }
        }
    }
    
    private func setupInit() {
        self.lastUpdatedTimeLabel?.isHidden = true
        self.isAutomaticallyChangeAlpha = true
        self.stateLabel?.font = .ddp_normal
        self.setTitle("", for: .idle)
        self.setTitle("", for: .pulling)
    }
}
