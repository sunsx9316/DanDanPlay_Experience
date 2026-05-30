//
//  FolderTableViewCell.swift
//  Runner
//
//  Created by jimhuang on 2021/3/29.
//

import UIKit
import Kingfisher

class FolderTableViewCell: TableViewCell {

    @IBOutlet weak var titleLabel: Label!

    @IBOutlet weak var imgView: UIImageView!

    private lazy var coverBackgroundView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.alpha = 0.25
        iv.clipsToBounds = true
        iv.setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
        iv.setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
        return iv
    }()

    var file: File? {
        didSet {
            self.titleLabel.text = self.file?.fileName
            if let coverURL = self.file?.coverImageURL {
                self.coverBackgroundView.kf.setImage(with: coverURL)
                self.coverBackgroundView.isHidden = false
            } else {
                self.coverBackgroundView.kf.cancelDownloadTask()
                self.coverBackgroundView.isHidden = true
                self.coverBackgroundView.image = nil
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.coverBackgroundView.frame = self.contentView.bounds
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.titleLabel.textColor = .textColor
        self.titleLabel.font = .ddp_normal

        self.contentView.clipsToBounds = true
        self.contentView.insertSubview(self.coverBackgroundView, at: 0)

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
