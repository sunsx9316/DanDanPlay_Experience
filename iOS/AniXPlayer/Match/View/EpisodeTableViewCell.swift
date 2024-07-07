//
//  EpisodeTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import UIKit

class EpisodeTableViewCell: TableViewCell {

    lazy var titleLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        return label
    }()
    
    var model: MatchItem? {
        didSet {
            self.titleLabel.text = self.model?.title
        }
    }
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    private func setupInit() {
        self.contentView.addSubview(self.titleLabel)
        
        self.titleLabel.snp.makeConstraints { (make) in
            make.edges.equalTo(UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        }
    }
    
}
