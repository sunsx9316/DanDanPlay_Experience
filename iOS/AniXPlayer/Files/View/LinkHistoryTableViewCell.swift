//
//  LinkHistoryTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/29.
//

import UIKit

class LinkHistoryTableViewCell: TableViewCell {

    lazy var titleLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    lazy var indicatorView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .gray)
        indicator.hidesWhenStopped = true
        indicator.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        indicator.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return indicator
    }()

    lazy var addressLabel: Label = {
        let label = Label()
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(indicatorView)
        contentView.addSubview(addressLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
            make.width.lessThanOrEqualTo(120)
        }

        indicatorView.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-10)
            make.leading.equalTo(addressLabel.snp.trailing).offset(10)
        }

        addressLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalTo(titleLabel.snp.trailing).offset(15)
            make.bottom.equalToSuperview().offset(-10)
        }

        self.setupInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.setupInit()
    }

    private func setupInit() {
        self.indicatorView.color = .darkGray
        self.titleLabel.text = nil
        self.addressLabel.text = nil
    }

}
