//
//  TitleDetailOpertationTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/20.
//

import UIKit

class TitleDetailOpertationTableViewCell: TableViewCell {

    @IBOutlet weak var titleLabel: Label!
    
    @IBOutlet weak var subtitleLabel: Label!
    
    @IBOutlet weak var button: UIButton!
    
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    var touchButtonCallBack: ((TitleDetailOpertationTableViewCell) -> Void)?
    
    var isShowLoading = false {
        didSet {
            if self.isShowLoading {
                self.indicatorView.startAnimating()
                self.indicatorView.isHidden = false
                self.button.isHidden = true
            } else {
                self.indicatorView.stopAnimating()
                self.indicatorView.isHidden = true
                self.button.isHidden = false
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.titleLabel.font = .ddp_large
        self.subtitleLabel.textColor = .subtitleTextColor
        self.isShowLoading = false
    }

    
    @IBAction func onTouchButton(_ sender: Button) {
        self.touchButtonCallBack?(self)
    }
    
}
