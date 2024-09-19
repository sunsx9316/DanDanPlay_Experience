//
//  TitleMoreTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/5.
//

import UIKit

class TitleMoreTableViewCell: TableViewCell {

    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var arrowImgView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear
        self.setupUI()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.setupUI()
    }
    
    
    private func setupUI() {
        self.arrowImgView.image = UIImage(named: "Public/right_arrow")?.byTintColor(.indicatorColor)
    }
}
