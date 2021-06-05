//
//  SwitchDetailTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/3.
//

import UIKit

class SwitchDetailTableViewCell: TableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var subtitleLabel: UILabel!
    
    @IBOutlet weak var aSwitch: UISwitch!
    
    var onTouchSliderCallBack: ((SwitchDetailTableViewCell) -> Void)?
    
    @IBAction func onTouchSwitch(_ sender: UISwitch) {
        self.onTouchSliderCallBack?(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.titleLabel.font = .ddp_large
        self.subtitleLabel.textColor = .subtitleTextColor
    }

    
}
