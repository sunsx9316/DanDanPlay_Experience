//
//  TitleDetailMoreTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/14.
//

import UIKit

class TitleDetailMoreTableViewCell: TableViewCell {
    
    @IBOutlet weak var titleLabel: Label!
    
    @IBOutlet weak var subtitleLabel: Label!
    
    @IBOutlet weak var arrowImgView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.titleLabel.font = .ddp_large
        self.subtitleLabel.textColor = .subtitleTextColor
        self.setupUI()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.setupUI()
    }
    
    
    private func setupUI() {
        self.arrowImgView.image = UIImage(named: "Public/right_arrow")?.byTintColor(.navItemColor)
    }
    
}
