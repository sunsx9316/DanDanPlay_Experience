//
//  TableViewCell.swift
//  Runner
//
//  Created by jimhuang on 2021/3/7.
//

import UIKit

class TableViewCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }

    private func setupInit() {
        self.selectedBackgroundView = UIView()
        self.selectedBackgroundView?.backgroundColor = .cellHighlightColor
        self.backgroundColor = .backgroundColor
    }

}
