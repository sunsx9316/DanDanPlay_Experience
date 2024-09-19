//
//  FilterDanmakuTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/3.
//

import UIKit

class FilterDanmakuTableViewCell: TableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var subtitleButton: Button!
    
    @IBOutlet weak var aSwitch: UISwitch!
    
    var onTouchSwitchCallBack: ((FilterDanmakuTableViewCell) -> Void)?
    
    var onTouchSubtitleButtonCallBack: ((FilterDanmakuTableViewCell) -> Void)?
    
    @IBAction func onTouchSwitch(_ sender: UISwitch) {
        self.onTouchSwitchCallBack?(self)
    }
    
    @IBAction func onTouchSubtitleButton(_ sender: UIButton) {
        self.onTouchSubtitleButtonCallBack?(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.titleLabel.font = .ddp_large
        self.subtitleButton.setTitleColor(.subtitleTextColor, for: .normal)
    }

    
}
