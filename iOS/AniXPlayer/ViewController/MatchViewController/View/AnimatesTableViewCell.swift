//
//  AnimatesTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import UIKit

class AnimatesTableViewCell: EpisodeTableViewCell {

    private lazy var typeLabel: Label = {
        let label = Label()
        label.backgroundColor = .mainColor
        label.textColor = .white
        label.font = .ddp_small
        label.layer.cornerRadius = 3
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.padding = .init(width: 6, height: 6)
        return label
    }()
    
    private lazy var arrowImgView: UIImageView = {
        let imgView = UIImageView()
        imgView.image = UIImage(named: "Comment/comment_right_arrow")
        imgView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imgView.setContentHuggingPriority(.required, for: .horizontal)
        return imgView
    }()
    
    override var model: MatchItem? {
        didSet {
            self.typeLabel.text = self.model?.typeDesc
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
        self.contentView.addSubview(self.typeLabel)
        self.contentView.addSubview(self.arrowImgView)
        
        self.typeLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(10)
            make.centerY.equalToSuperview()
        }
        
        self.titleLabel.snp.remakeConstraints { (make) in
            make.leading.equalTo(self.typeLabel.snp.trailing).offset(10)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }
        
        self.arrowImgView.snp.makeConstraints { (make) in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(self.titleLabel.snp.trailing).offset(10)
        }
    }
}
