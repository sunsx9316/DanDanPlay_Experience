//
//  SnapshotView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/5/4.
//

import UIKit
import SnapKit

class SnapshotView: UIView {
    
    private lazy var imgView = UIImageView()
    
    private lazy var timeLabel: Label = {
        let label = Label()
        return label
    }()
    
    private var thumbnailer: MediaThumbnailer?
    
    private let timeFormatter: DateFormatter
    
    init(timeFormatter: DateFormatter, thumbnailer: MediaThumbnailer?) {
        self.timeFormatter = timeFormatter
        self.thumbnailer = thumbnailer
        super.init(frame: .zero)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ currentTime: TimeInterval, totalTime: TimeInterval) {
        let img = self.thumbnailer?.snapshot(at: Int(currentTime))
        self.imgView.image = img
        
        let current = Date(timeIntervalSince1970: currentTime)
        let total = Date(timeIntervalSince1970: totalTime)
        self.timeLabel.text = timeFormatter.string(from: current) + "/" + timeFormatter.string(from: total)
    }
    
    private func setupInit() {
        self.addSubview(self.imgView)
        self.addSubview(self.timeLabel)
        
        self.imgView.snp.makeConstraints { make in
            make.top.leading.equalTo(10)
            make.trailing.equalTo(-10)
            make.size.equalTo(CGSize(width: 100, height: 40))
        }
        
        self.timeLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(self.imgView)
            make.top.equalTo(self.imgView.snp.bottom).offset(5)
            make.bottom.equalTo(-10)
        }
    }
}
