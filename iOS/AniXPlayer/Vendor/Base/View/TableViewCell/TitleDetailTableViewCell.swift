//
//  TitleDetailTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/3.
//

import UIKit

class TitleDetailTableViewCell: TableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.titleLabel.font = .ddp_large
        self.subtitleLabel.textColor = .subtitleTextColor
    }
    
}
