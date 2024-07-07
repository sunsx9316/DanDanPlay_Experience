//
//  FolderTableViewCell.swift
//  Runner
//
//  Created by jimhuang on 2021/3/29.
//

import UIKit

class FolderTableViewCell: TableViewCell {
    
    @IBOutlet weak var titleLabel: Label!
    
    @IBOutlet weak var imgView: UIImageView!
    

    var file: File? {
        didSet {
            self.titleLabel.text = self.file?.fileName
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.titleLabel.textColor = .textColor
        self.titleLabel.font = .ddp_normal
        self.setupUI()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.setupUI()
    }
    
    private func setupUI() {
        self.imgView.image = UIImage(named: "Public/folder")?.byTintColor(.mainColor)
    }
    
}
