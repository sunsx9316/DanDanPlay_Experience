//
//  TitleTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa

class TitleTableViewCell: NSView {

    @IBOutlet weak var label: NSTextField!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.label.text = nil
        self.label.toolTip = nil
    }
    
}
