//
//  FavoriteCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SDWebImage
import SVGKit
import YYCategories

class FavoriteCollectionViewCell: CollectionViewCell {
    
    @IBOutlet weak var imgView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var ratingLabel: UILabel!
    
    @IBOutlet weak var favoritedButton: UIButton!
    
    @IBOutlet weak var isOnAirLabel: UILabel!
    
    @IBOutlet weak var lastWatchTimeLabel: UILabel!
    
    var didTouchLikeButton: ((FavoriteCollectionViewCell, Bool) -> Void)?
    
    func update(item: UserFavoriteItem?, ratingNumberFormatter: NumberFormatter, dateFormatter: DateFormatter) {
        self.item = item
        
        if let url = self.item?.imageUrl {
            self.imgView.sd_setImage(with: URL(string: url))
        } else {
            self.imgView.image = nil
        }
        
        self.titleLabel.text = self.item?.animeTitle
        self.ratingLabel.text = ratingNumberFormatter.string(from: NSNumber(value: self.item?.rating ?? 0))
        self.isOnAirLabel.text = self.item?.isOnAir == true ? NSLocalizedString("连载中", comment: "") : "已完结"
        changeFavoritedStatus(isFavorited: self.item?.favoriteStatus == .favorited)
        if let lastWatchTimeDate = self.item?.lastWatchTime {
            self.lastWatchTimeLabel.text = NSLocalizedString("上次观看时间：", comment: "") + dateFormatter.string(from: lastWatchTimeDate)
        } else {
            self.lastWatchTimeLabel.text = nil
        }
    }
    
    var item: UserFavoriteItem?
    
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
        let isFavorited = self.item?.favoriteStatus == .favorited
        self.didTouchLikeButton?(self, !isFavorited)
        changeFavoritedStatus(isFavorited: !isFavorited)
    }
    
    private func changeFavoritedStatus(isFavorited: Bool) {
        if isFavorited {
            if let svgImage = SVGKImage(named: "Like.svg", withCacheKey: "Like.svg") {
                svgImage.size = CGSize(width: 20, height: 20)
                self.favoritedButton.setImage(svgImage.uiImage.byTintColor(.mainColor), for: .normal)
            } else {
                self.favoritedButton.setImage(nil, for: .normal)
            }
        } else {
            if let svgImage = SVGKImage(named: "Unlike.svg", withCacheKey: "Unlike.svg") {
                svgImage.size = CGSize(width: 20, height: 20)
                self.favoritedButton.setImage(svgImage.uiImage.byTintColor(.mainColor), for: .normal)
            } else {
                self.favoritedButton.setImage(nil, for: .normal)
            }
        }
    }
    
}
