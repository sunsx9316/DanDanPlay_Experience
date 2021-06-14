//
//  EditableTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/14.
//

import UIKit

class EditableTableViewCell: TableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear
        self.titleLabel.textColor = .textColor
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if let reorderView = self.findReorderView() {
            for view in reorderView.subviews {
                if let imgView = view as? UIImageView {
                    imgView.image = UIImage(named: "Comment/sort")
                }
            }
        }
    }
    
    func findReorderView() -> UIView? {
        var subviews = self.subviews
        var index = 0
        while index < subviews.count {
            let view = subviews[index]
            if view.className().contains("ReorderControl") {
                return view
            } else {
                subviews.append(contentsOf: view.subviews)
            }
            index += 1
        }
        
        return nil
    }
    
}
