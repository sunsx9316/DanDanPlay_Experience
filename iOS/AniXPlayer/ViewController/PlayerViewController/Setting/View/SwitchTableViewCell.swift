//
//  SwitchTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/22.
//

import UIKit

class SwitchTableViewCell: TableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var aSwitch: UISwitch!
    
    var onTouchSliderCallBack: ((SwitchTableViewCell) -> Void)?
    
    @IBAction func onTouchSwitch(_ sender: UISwitch) {
        self.onTouchSliderCallBack?(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear
    }
    
}
