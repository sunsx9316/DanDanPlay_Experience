//
//  LinkHistoryTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/29.
//

import UIKit

class LinkHistoryTableViewCell: TableViewCell {
    
    @IBOutlet weak var titleLabel: Label!
    
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    @IBOutlet weak var addressLabel: Label!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.setupInit()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.setupInit()
    }
    
    private func setupInit() {
        self.indicatorView.color = .darkGray
        self.titleLabel.text = nil
        self.addressLabel.text = nil
    }
    
}
