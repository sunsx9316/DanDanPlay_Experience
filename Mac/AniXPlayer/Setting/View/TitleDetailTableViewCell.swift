//
//  TitleDetailTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa

class TitleDetailTableViewCell: NSView {

    @IBOutlet weak var titleLabel: NSTextField!
    
    @IBOutlet weak var subtitleLabel: NSTextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.titleLabel.font = .ddp_large
        self.subtitleLabel.textColor = .subtitleTextColor
    }
}
