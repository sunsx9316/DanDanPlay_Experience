//
//  TableView.swift
//  AniXPlayer
//
//  tvOS TableView 基类 — 焦点相关配置
//

import UIKit

class TableView: UITableView {

    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        self.setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    private func setup() {
        self.backgroundColor = .black
        self.remembersLastFocusedIndexPath = true
    }
}
