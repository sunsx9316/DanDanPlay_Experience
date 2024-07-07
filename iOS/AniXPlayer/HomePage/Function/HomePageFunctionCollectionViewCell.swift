//
//  HomePageFunctionCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit

struct HomePageFunctionItem {
    
    enum ItemType {
        case timeLine
    }
    
    var itemType: ItemType
    
    var img: UIImage
    
    var name: String
    
}

class HomePageFunctionCollectionViewCell: CollectionViewCell {

    @IBOutlet weak var imgView: UIImageView!
    
    @IBOutlet weak var nameLabel: Label!
    
    var item: HomePageFunctionItem? {
        didSet {
            self.imgView.image = self.item?.img
            self.nameLabel.text = self.item?.name
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.nameLabel.font = .ddp_small
    }

}
