//
//  FileTableViewCell.swift
//  Runner
//
//  Created by jimhuang on 2021/3/29.
//

import UIKit

class FileTableViewCell: TableViewCell {
    
    @IBOutlet weak var typeLabel: Label!
    
    @IBOutlet weak var titleLabel: Label!
    
    var file: File? {
        didSet {
            self.typeLabel.text = self.file?.pathExtension.isEmpty == false ? self.file?.pathExtension : "?"
            self.titleLabel?.text = self.file?.fileName
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.typeLabel.font = .ddp_large
        self.typeLabel?.backgroundColor = .mainColor
        self.typeLabel.textColor = .white
        self.typeLabel.layer.masksToBounds = true
        self.typeLabel.layer.cornerRadius = 6
        
        self.titleLabel.font = .ddp_normal
    }
}
