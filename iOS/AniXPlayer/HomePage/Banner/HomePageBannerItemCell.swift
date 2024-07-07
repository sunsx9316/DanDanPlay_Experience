//
//  HomePageBannerItemCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit
import SDWebImage
import YYCategories
import FSPagerView

class HomePageBannerItemCell: FSPagerViewCell {

    @IBOutlet weak var bgImageView: UIImageView!
    
    @IBOutlet weak var titleLabel: Label!
    
    @IBOutlet weak var descLabel: Label!
    
    var item: BannerPageItem? {
        didSet {
            if let imageUrl = self.item?.imageUrl {
                self.bgImageView.sd_setImage(with: URL(string: imageUrl))
            } else {
                self.bgImageView.image = nil
            }
            self.titleLabel.text = self.item?.title
            self.descLabel.text = self.item?.description
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        titleLabel.font = .ddp_large
        descLabel.font = .ddp_small
        
        titleLabel.setLayerShadow(.shadowColor, offset: CGSize(width: 0, height: 1), radius: 3)
        descLabel.setLayerShadow(.shadowColor, offset: CGSize(width: 0, height: 1), radius: 3)
    }

}
