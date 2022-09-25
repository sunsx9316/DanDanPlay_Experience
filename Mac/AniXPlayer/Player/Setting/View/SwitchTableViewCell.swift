//
//  SwitchTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa

class SwitchTableViewCell: NSView {

    @IBOutlet weak var aSwitch: NSButton!
    
    var onTouchSliderCallBack: ((SwitchTableViewCell) -> Void)?
    
    @IBAction func onTouchSwitch(_ sender: NSButton) {
        self.onTouchSliderCallBack?(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.aSwitch.font = .ddp_normal
    }
 
}
