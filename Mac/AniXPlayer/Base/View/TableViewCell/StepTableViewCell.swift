//
//  StepTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa

class StepTableViewCell: NSView {
    
    @IBOutlet weak var titleLabel: NSTextField!
    
    @IBOutlet weak var stepper: NSStepper!
    
    @IBOutlet weak var valueLabel: NSTextField!
    
    var onTouchStepperCallBack: ((StepTableViewCell) -> Void)?
    
    
    @IBAction func onTouchStepper(_ sender: NSStepper) {
        self.onTouchStepperCallBack?(self)
    }
}
