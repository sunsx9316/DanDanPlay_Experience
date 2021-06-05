//
//  LinkHistoryHeaderView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/30.
//

import UIKit
import SnapKit

class LinkHistoryHeaderView: UITableViewHeaderFooterView {
    
    lazy var titleLabel: Label = {
        let titleLabel = Label()
        titleLabel.font = .ddp_small
        return titleLabel
    }()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    //MARK: Private
    private func setupInit() {
        self.backgroundView = .init()
        self.backgroundView?.backgroundColor = .headViewBackgroundColor
        self.contentView.addSubview(self.titleLabel)
        self.titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(10)
            make.centerY.equalToSuperview()
        }
    }
    
}
