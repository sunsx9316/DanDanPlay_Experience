//
//  TableView.swift
//  Runner
//
//  Created by jimhuang on 2021/3/7.
//

import UIKit

class TableView: UITableView {
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    private func setupInit() {
        self.backgroundColor = .backgroundColor;
        self.estimatedRowHeight = 0
        self.estimatedSectionHeaderHeight = 0
        self.estimatedSectionFooterHeight = 0
        self.contentInsetAdjustmentBehavior = .automatic
        self.tableFooterView = UIView()
    }
}
