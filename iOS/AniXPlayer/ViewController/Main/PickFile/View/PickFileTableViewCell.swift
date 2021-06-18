//
//  PickFileTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/1.
//

import UIKit

class PickFileTableViewCell: TableViewCell {

    @IBOutlet weak var iconImgView: UIImageView!
    
    @IBOutlet weak var titleLabel: Label!
    
    @IBOutlet weak var arrowImgView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.setupUI()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.setupUI()
    }
    
    //MARK: Private
    private func setupUI() {
        self.arrowImgView.image = UIImage(named: "Public/right_arrow")?.byTintColor(.navItemColor)
    }
}
