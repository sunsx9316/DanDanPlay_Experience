//
//  StepTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/22.
//

import UIKit

class StepTableViewCell: TableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var valueLabel: UILabel!
    
    @IBOutlet weak var stepper: UIStepper!
    
    var onTouchStepperCallBack: ((StepTableViewCell) -> Void)?
    
    
    @IBAction func onTouchStepper(_ sender: UIStepper) {
        self.onTouchStepperCallBack?(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear
        self.titleLabel.textColor = .white
        self.valueLabel.textColor = .white
        self.stepper.tintColor = .white
    }
    
}
