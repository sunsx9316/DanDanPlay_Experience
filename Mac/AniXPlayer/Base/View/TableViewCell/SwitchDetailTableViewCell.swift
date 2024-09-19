//
//  SwitchDetailTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa

class SwitchDetailTableViewCell: NSView {
    
    @IBOutlet weak var titleLabel: NSTextField!
    
    @IBOutlet weak var subtitleLabel: NSTextField!
    
    @IBOutlet weak var aSwitch: NSSwitch!
    
    var onTouchSwitchCallBack: ((SwitchDetailTableViewCell) -> Void)?
    
    @IBAction func onTouchSwitch(_ sender: NSSwitch) {
        self.onTouchSwitchCallBack?(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.titleLabel.font = .ddp_large
        self.subtitleLabel.textColor = .subtitleTextColor
    }
    
}
