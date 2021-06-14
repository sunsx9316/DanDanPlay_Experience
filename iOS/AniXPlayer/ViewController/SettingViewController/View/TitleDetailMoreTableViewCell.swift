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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.titleLabel.font = .ddp_large
        self.subtitleLabel.textColor = .subtitleTextColor
    }
    
}
