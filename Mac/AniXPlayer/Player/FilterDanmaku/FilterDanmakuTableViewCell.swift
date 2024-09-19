//
//  FilterDanmakuTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa

class FilterDanmakuTableViewCell: NSView {
    
    @IBOutlet weak var titleLabel: NSTextField!
    
    @IBOutlet weak var checkbox: NSButton!
    
    @IBOutlet weak var aSwitch: NSSwitch!
    
    var onClickSwitchCallBack: ((FilterDanmakuTableViewCell) -> Void)?
    var onClickCheckCallBack: ((FilterDanmakuTableViewCell) -> Void)?
    
    @IBAction func onTouchSwitch(_ sender: NSSwitch) {
        self.onClickSwitchCallBack?(self)
    }
    
    @IBAction func onClickCheckButton(_ sender: NSButton) {
        self.onClickCheckCallBack?(self)
    }
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.titleLabel.font = .ddp_small
        self.checkbox.font = .ddp_small
    }
    
}
