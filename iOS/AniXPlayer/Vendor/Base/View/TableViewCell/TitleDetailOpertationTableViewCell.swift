//
//  TitleDetailOpertationTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/20.
//

import UIKit
import SnapKit

class TitleDetailOpertationTableViewCell: TableViewCell {

    lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large
        label.numberOfLines = 0
        return label
    }()

    lazy var subtitleLabel: Label = {
        let label = Label()
        label.textColor = .subtitleTextColor
        label.numberOfLines = 0
        label.setContentHuggingPriority(.init(249), for: .vertical)
        label.setContentCompressionResistancePriority(.init(748), for: .vertical)
        return label
    }()

    lazy var button: Button = {
        let btn = Button()
        btn.setTitleColor(.textColor, for: .normal)
        return btn
    }()

    lazy var indicatorView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .gray)
        indicator.hidesWhenStopped = true
        return indicator
    }()

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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(button)
        contentView.addSubview(indicatorView)

        button.addTarget(self, action: #selector(onTouchButton(_:)), for: .touchUpInside)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(15)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-10)
        }

        button.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(10)
            make.leading.greaterThanOrEqualTo(subtitleLabel.snp.trailing).offset(10)
        }

        indicatorView.snp.makeConstraints { make in
            make.centerX.equalTo(button)
            make.centerY.equalTo(button)
        }

        self.isShowLoading = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onTouchButton(_ sender: Button) {
        self.touchButtonCallBack?(self)
    }
}
