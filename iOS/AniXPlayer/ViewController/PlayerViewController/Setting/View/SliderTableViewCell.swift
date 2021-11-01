//
//  SliderTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/20.
//

import UIKit

class SliderTableViewCell: TableViewCell {
    
    struct Model {
        
        var maxValue: Float
        
        var minValue: Float
        
        var currentValue: Float
        
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var minValueLabel: UILabel!
    
    @IBOutlet weak var maxValueLabel: UILabel!
    
    @IBOutlet weak var valueSlider: UISlider!
    
    @IBOutlet weak var currentValueLabel: UILabel!
    
    var step: UInt = 0
    
    var onChangeSliderCallBack: ((SliderTableViewCell) -> Void)?
    
    var model: Model? {
        didSet {
            if let model = self.model {
                self.minValueLabel.text = String(format: "%.1f", model.minValue)
                self.maxValueLabel.text = String(format: "%.1f", model.maxValue)
                self.currentValueLabel.text = String(format: "%.1f", model.currentValue)
                self.valueSlider.minimumValue = model.minValue
                self.valueSlider.maximumValue = model.maxValue
                self.changeValue(model.currentValue)
            } else {
                self.minValueLabel.text = nil
                self.maxValueLabel.text = nil
                self.currentValueLabel.text = nil
                self.valueSlider.minimumValue = 0
                self.valueSlider.maximumValue = 0
                self.changeValue(0)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear
        self.titleLabel.textColor = .white
        self.minValueLabel.textColor = .white
        self.maxValueLabel.textColor = .white
        self.currentValueLabel.textColor = .white
    }
    
    @IBAction func onChangeSlider(_ sender: UISlider) {
        self.changeValue(sender.value)
        self.onChangeSliderCallBack?(self)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.step = 0
        self.valueSlider.isContinuous = true
    }
    
    private func changeValue(_ value: Float) {
        if self.step != 0 {
            let newStep = Float(self.step)
            let newValue = round(value / newStep) * newStep
            if newValue != self.valueSlider.value {
                self.valueSlider.value = newValue
            }
        } else {
            if self.valueSlider.value != value {
                self.valueSlider.value = value
            }
        }
    }
    
    
}
