//
//  SliderTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/20.
//

import UIKit

typealias SliderModelFormatterAction = (SliderTableViewCell.Model) -> String

class SliderTableViewCell: TableViewCell {
    
    class Model {
        
        var maxValue: Float
        
        var minValue: Float
        
        var currentValue: Float
        
        var maxValueFormattingCallBack: SliderModelFormatterAction?
        
        var minValueFormattingCallBack: SliderModelFormatterAction?

        var currentValueFormattingCallBack: SliderModelFormatterAction?
        
        init(maxValue: Float, minValue: Float, currentValue: Float) {
            self.currentValue = currentValue
            self.minValue = minValue
            self.maxValue = maxValue
            
            self.minValueFormattingCallBack = { value in
                return String(format: "%.1f", value.minValue)
            }
            
            self.maxValueFormattingCallBack = { value in
                return String(format: "%.1f", value.maxValue)
            }
            
            self.currentValueFormattingCallBack = { value in
                return String(format: "%.1f", value.currentValue)
            }
        }
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var minValueLabel: UILabel!
    
    @IBOutlet weak var maxValueLabel: UILabel!
    
    @IBOutlet weak var valueSlider: UISlider!
    
    @IBOutlet weak var currentValueLabel: UILabel!
    
    /// 步长
    var step: Float = 0
    
    var onChangeSliderCallBack: ((SliderTableViewCell) -> Void)?
    
    var model: Model? {
        didSet {
            if let model = self.model {
                self.minValueLabel.text = model.minValueFormattingCallBack?(model) ?? ""
                self.maxValueLabel.text = model.maxValueFormattingCallBack?(model) ?? ""
                self.currentValueLabel.text = model.currentValueFormattingCallBack?(model) ?? ""
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
        self.valueSlider.isContinuous = false
    }
    
    @IBAction func onChangeSlider(_ sender: UISlider) {
        self.changeValue(sender.value)
        self.onChangeSliderCallBack?(self)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.step = 0
        self.valueSlider.isContinuous = false
    }
    
    private func changeValue(_ value: Float) {
        if self.step != 0 {
            let newStep = self.step
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
