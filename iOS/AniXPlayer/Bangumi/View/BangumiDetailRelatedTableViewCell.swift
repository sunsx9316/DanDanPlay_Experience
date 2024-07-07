//
//  BangumiDetailRelatedTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SnapKit

class BangumiDetailRelatedTableViewCell: TableViewCell {
    
    lazy var titleLabel: Label = {
        var titleLabel = Label()
        titleLabel.font = .ddp_large
        return titleLabel
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var timelineVC: TimelineItemViewController = {
        var timelineVC = TimelineItemViewController(scrollDirection: .horizontal, dataSources: nil)
        timelineVC.didSelectedAnimateCallBack = { [weak self] animateId in
            guard let self = self else { return }
            
            self.didSelectedAnimateCallBack?(animateId)
        }
        return timelineVC
    }()
    
    var didSelectedAnimateCallBack: ((Int) -> Void)?
    
    var bangumiIntros: [BangumiIntro]? {
        didSet {
            self.timelineVC.dataSources = self.bangumiIntros
        }
    }
    
    private func setupInit() {
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.timelineVC.view)
        self.selectedBackgroundView?.backgroundColor = nil
        
        self.titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(10)
        }
        
        self.timelineVC.view.snp.makeConstraints { make in
            make.top.equalTo(self.titleLabel.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
