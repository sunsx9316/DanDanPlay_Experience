//
//  TitleTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/5.
//

import UIKit

class TitleTableViewCell: TableViewCell {

    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear
        self.label.textColor = .white
    }
}
