//
//  SnapshotPreviewView.swift
//  AniXPlayer
//
//  进度条缩略图预览（缩略图 + 时间）
//

import UIKit

class SnapshotPreviewView: UIView {

    private static let imageWidth: CGFloat = 160
    private static let imageHeight: CGFloat = 90

    private lazy var imgView: UIImageView = {
        let imgView = UIImageView()
        imgView.contentMode = .scaleAspectFit
        imgView.backgroundColor = .black
        imgView.layer.cornerRadius = 4
        imgView.layer.masksToBounds = true
        imgView.isHidden = true
        return imgView
    }()

    private lazy var timeLabel: Label = {
        let label = Label()
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        return label
    }()

    private(set) var hasThumbnail = false

    var timeText: String? {
        didSet {
            self.timeLabel.text = self.timeText
        }
    }

    /// 期望尺寸：有缩略图时更大
    var desiredSize: CGSize {
        if self.hasThumbnail {
            return CGSize(width: Self.imageWidth + 16, height: Self.imageHeight + 4 + 18 + 16)
        }
        return CGSize(width: 100, height: 8 + 18 + 8)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }

    /// 设置缩略图（nil 表示无/加载失败）
    func setThumbnail(_ image: ANXImage?) {
        self.hasThumbnail = image != nil
        self.imgView.image = image
        self.imgView.isHidden = image == nil
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let padding: CGFloat = 8
        if self.hasThumbnail {
            let width = min(Self.imageWidth, self.bounds.width - padding * 2)
            self.imgView.frame = CGRect(x: padding, y: padding, width: width, height: Self.imageHeight)
            self.timeLabel.frame = CGRect(x: padding, y: self.imgView.frame.maxY + 4, width: width, height: 18)
        } else {
            self.imgView.frame = .zero
            self.timeLabel.frame = self.bounds.insetBy(dx: padding, dy: padding)
        }
    }

    private func setupInit() {
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        self.layer.cornerRadius = 6
        self.layer.masksToBounds = true
        self.isUserInteractionEnabled = false
        self.addSubview(self.imgView)
        self.addSubview(self.timeLabel)
    }
}
