//
//  FavoriteCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import Kingfisher
import YYCategories

class TimelineItemCollectionViewCell: CollectionViewCell {
    
    @IBOutlet weak var imgView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var ratingLabel: UILabel!
    
    @IBOutlet weak var favoritedButton: UIButton!
    
    @IBOutlet weak var isOnAirLabel: UILabel!
    
    var didTouchLikeButton: ((TimelineItemCollectionViewCell, Bool) -> Void)?
    
    func update(item: BangumiIntro?, ratingNumberFormatter: NumberFormatter) {
        self.item = item
        
        if let url = self.item?.imageUrl {
            self.imgView.kf.setImage(with: URL(string: url))
        } else {
            self.imgView.image = nil
        }
        
        self.titleLabel.text = self.item?.animeTitle
        self.ratingLabel.text = ratingNumberFormatter.string(from: NSNumber(value: self.item?.rating ?? 0))
        self.isOnAirLabel.text = self.item?.isOnAir == true ? NSLocalizedString("连载中", comment: "") : "已完结"
        changeFavoritedStatus(isFavorited: self.item?.isFavorited == true)
    }
    
    var item: BangumiIntro?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.titleLabel.font = .ddp_large
        self.isOnAirLabel.font = .ddp_normal
        self.isOnAirLabel.textColor = .subtitleTextColor
        
        self.ratingLabel.font = UIFont.boldSystemFont(ofSize: 18)
        self.ratingLabel.textColor = .mainColor
        self.favoritedButton.setTitle(nil, for: .normal)
    }

    @IBAction func onTouchLikeButton(_ sender: Button) {
        let isFavorited = self.item?.isFavorited == true
        self.didTouchLikeButton?(self, !isFavorited)
        changeFavoritedStatus(isFavorited: !isFavorited)
    }
    
    private func changeFavoritedStatus(isFavorited: Bool) {
        let imageName = isFavorited ? "Like" : "Unlike"
        self.favoritedButton.setImage(UIImage(named: imageName)?.byResize(to: CGSize(width: 20, height: 20))?.byTintColor(.mainColor), for: .normal)
    }
    
}
