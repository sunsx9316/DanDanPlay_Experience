//
//  PlayerListTableViewCell.swift
//  Runner
//
//  Created by JimHuang on 2020/3/8.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa

class PlayerListTableViewCell: NSView {

    @IBOutlet weak var pointView: NSView!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var labelLeadingConstraint: NSLayoutConstraint!
    
    var showPoint: Bool = false {
        didSet {
            pointView.isHidden = !self.showPoint
            if self.showPoint {
                labelLeadingConstraint?.constant = 21
            } else {
                labelLeadingConstraint?.constant = 7
            }
        }
    }
    
    var string: String? {
        didSet {
            self.label.stringValue = self.string ?? ""
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        pointView.wantsLayer = true
        pointView.layer?.cornerRadius = 3.5
        pointView.layer?.masksToBounds = true
        pointView.layer?.backgroundColor = NSColor.green.cgColor
    }
    
}
