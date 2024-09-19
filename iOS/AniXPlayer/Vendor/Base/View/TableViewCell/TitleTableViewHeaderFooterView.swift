//
//  TitleTableViewHeaderFooterView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/17.
//

import UIKit
import SnapKit

class TitleTableViewHeaderFooterView: UITableViewHeaderFooterView {

    lazy var titleLabel: Label = {
        var titleLabel = Label()
        titleLabel.numberOfLines = 0
        titleLabel.font = .ddp_large
        return titleLabel
    }()
    
    private lazy var bgView: UIVisualEffectView = {
        var topLineView = UIVisualEffectView()
        if #available(iOS 12.0, *) {
            if self.traitCollection.userInterfaceStyle == .dark {
                topLineView.effect = UIBlurEffect(style: .dark)
            } else {
                topLineView.effect = UIBlurEffect(style: .light)
            }
        } else {
            topLineView.effect = UIBlurEffect(style: .light)
        }
        return topLineView
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.contentView.addSubview(self.bgView)
        self.contentView.addSubview(self.titleLabel)
        
        self.titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(15)
            make.top.equalTo(10)
            make.bottom.equalTo(-10)
            make.trailing.equalTo(-10)
        }
        
        self.bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
