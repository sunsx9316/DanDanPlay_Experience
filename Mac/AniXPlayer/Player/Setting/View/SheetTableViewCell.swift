//
//  SheetTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa

class SheetTableViewCell: NSView {

    @IBOutlet weak var titleLabel: TextField!
    
    @IBOutlet weak var popUpButton: NSPopUpButton!
    
    var onClickButtonCallBack: ((Int) -> Void)?
    
    func setItems(_ items: [String], selectedItem: String?) {
        self.popUpButton.removeAllItems()
        self.popUpButton.addItems(withTitles: items)
        if let selectedItem = selectedItem {
            self.popUpButton.selectItem(withTitle: selectedItem)            
        }
    }
    
    @IBAction func onClickButton(_ sender: NSPopUpButton) {
        self.onClickButtonCallBack?(sender.indexOfSelectedItem)
    }
}
