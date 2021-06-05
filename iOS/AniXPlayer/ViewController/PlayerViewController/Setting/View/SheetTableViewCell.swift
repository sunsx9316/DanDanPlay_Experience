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
        self.arrowImgView.image = UIImage(named: "Comment/comment_arrow_down")?.byTintColor(.backgroundColor)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear
    }
}
