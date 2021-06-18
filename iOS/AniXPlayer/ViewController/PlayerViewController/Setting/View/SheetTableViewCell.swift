//
//  SheetTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/23.
//

import UIKit

class SheetTableViewCell: TableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var arrowImgView: UIImageView!
    
    @IBOutlet weak var valueLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear
        self.titleLabel.textColor = .white
        self.valueLabel.textColor = .white
        self.arrowImgView.image = UIImage(named: "Public/right_arrow")?.byTintColor(.white)
    }
}
