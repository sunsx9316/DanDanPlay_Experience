//
//  FileTableViewCell.swift
//  Runner
//
//  Created by jimhuang on 2021/3/29.
//

import UIKit
import SnapKit

class FileTableViewCell: TableViewCell {
    
    private lazy var typeLabel: Label = {
        let label = Label()
        label.font = .ddp_large
        label.backgroundColor = .mainColor
        label.textColor = .white
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 6
        label.textAlignment = .center
        return label
    }()
    
    private var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_normal
        label.numberOfLines = 0
        return label
    }()
    
    private var subtitleLabel: Label = {
        let label = Label()
        label.font = .ddp_small
        label.textColor = .subtitleTextColor
        label.numberOfLines = 0
        return label
    }()
    
    private var lastWatchDateLabel: Label = {
        let label = Label()
        label.font = .ddp_small
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.textColor = .subtitleTextColor
        return label
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 5
        return stackView
    }()
    
    var file: File? {
        didSet {
            self.typeLabel.text = self.file?.pathExtension.isEmpty == false ? self.file?.pathExtension : "?"
            self.titleLabel.text = self.file?.fileName
            self.subtitleLabel.text = self.file?.subtitle
            if let file = self.file, let lastWatchDate = HistoryManager.shared.lastWatchDate(media: file) {
                let dateFormatter = DateFormatter.anix_YYYY_MM_dd_HH_mm_ssFormatter
                self.lastWatchDateLabel.text = NSLocalizedString("上次播放时间:", comment: "") + dateFormatter.string(from: lastWatchDate)
            }
            
            self.subtitleLabel.isHidden = !(self.subtitleLabel.text?.isEmpty == false)
            self.lastWatchDateLabel.isHidden = !(self.lastWatchDateLabel.text?.isEmpty == false)
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.stackView.addArrangedSubview(self.titleLabel)
        self.stackView.addArrangedSubview(self.subtitleLabel)
        self.stackView.addArrangedSubview(self.lastWatchDateLabel)
        
        self.contentView.addSubview(self.typeLabel)
        self.contentView.addSubview(self.stackView)
        
        self.typeLabel.snp.makeConstraints { make in
            make.top.leading.equalTo(10)
            make.width.height.equalTo(50)
            make.bottom.lessThanOrEqualTo(-10)
        }
        
        self.stackView.snp.makeConstraints { make in
            make.top.equalTo(self.typeLabel.snp.top).offset(2)
            make.leading.equalTo(self.typeLabel.snp.trailing).offset(10)
            make.trailing.equalTo(-10)
            make.bottom.lessThanOrEqualTo(-10)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
