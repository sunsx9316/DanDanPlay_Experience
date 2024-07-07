//
//  BangumiDetailInfoViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SDWebImage
import SVGKit
import YYCategories

class BangumiDetailInfoViewCell: TableViewCell {
    
    @IBOutlet weak var imgView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var ratingLabel: UILabel!
    
    @IBOutlet weak var favoritedButton: UIButton!
    
    @IBOutlet weak var isOnAirLabel: UILabel!
    
    @IBOutlet weak var tagsLabel: UILabel!
    
    @IBOutlet weak var arrowButton: Button!
    
    var didTouchLikeButton: ((Bool) -> Void)?
    
    var touchArrowButton: (() -> Void)?
    
    func update(item: BangumiDetail?, ratingNumberFormatter: NumberFormatter) {
        self.item = item
        
        if let url = self.item?.imageUrl {
            self.imgView.sd_setImage(with: URL(string: url))
        } else {
            self.imgView.image = nil
        }
        
        self.titleLabel.text = self.item?.animeTitle
        self.ratingLabel.text = ratingNumberFormatter.string(from: NSNumber(value: self.item?.rating ?? 0))
        self.isOnAirLabel.text = self.item?.isOnAir == true ? NSLocalizedString("连载中", comment: "") : "已完结"
        
        if self.item?.isFavorited == true {
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
        
        if let tags = item?.tags {
            let sortTags = tags.sorted { tag1, tag2 in
                return tag1.count > tag2.count
            }
            
            self.tagsLabel.text = sortTags.reduce("") { partialResult, tag in
                if partialResult.isEmpty {
                    return tag.name
                }
                return partialResult + ", " + tag.name
            }
        } else {
            self.tagsLabel.text = nil
        }
    }
    
    private(set) var item: BangumiDetail?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.titleLabel.font = .ddp_large
        
        self.isOnAirLabel.font = .ddp_normal
        self.isOnAirLabel.textColor = .subtitleTextColor
        
        self.ratingLabel.font = UIFont.boldSystemFont(ofSize: 18)
        self.ratingLabel.textColor = .mainColor
        
        self.tagsLabel.font = .ddp_small
        self.tagsLabel.textColor = .subtitleTextColor
        
        self.favoritedButton.setTitle(nil, for: .normal)
        
        self.arrowButton.setTitle(nil, for: .normal)
        self.arrowButton.setImage(UIImage(named: "Public/right_arrow")?.byTintColor(.navItemColor), for: .normal)
        self.arrowButton.touchAreaEdgeInsets = .init(top: -30, left: -10, bottom: -30, right: -10)
    }

    @IBAction func onTouchLikeButton(_ sender: Button) {
        let isFavorited = self.item?.isFavorited == true
        self.didTouchLikeButton?(!isFavorited)
    }

    @IBAction func onTouchArrowButton(_ sender: UIButton) {
        self.touchArrowButton?()
    }
    
}
