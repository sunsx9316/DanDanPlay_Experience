//
//  SliderTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa

typealias SliderModelFormatterAction = (SliderTableViewCell.Model) -> String

class SliderTableViewCell: NSView {
    
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
    
    @IBOutlet weak var titleLabel: NSTextField!
    
    @IBOutlet weak var currentValueLabel: NSTextField!
    
    @IBOutlet weak var minValueLabel: NSTextField!
    
    @IBOutlet weak var maxValueLabel: NSTextField!
    
    @IBOutlet weak var valueSlider: NSSlider!
    
    /// 步长
    var step: UInt = 0
    
    var onChangeSliderCallBack: ((SliderTableViewCell) -> Void)?
    
    var model: Model? {
        didSet {
            if let model = self.model {
                self.minValueLabel.stringValue = model.minValueFormattingCallBack?(model) ?? ""
                self.maxValueLabel.stringValue = model.maxValueFormattingCallBack?(model) ?? ""
                self.currentValueLabel.stringValue = model.currentValueFormattingCallBack?(model) ?? ""
                self.valueSlider.minValue = Double(model.minValue)
                self.valueSlider.maxValue = Double(model.maxValue)
                self.changeValue(model.currentValue)
            } else {
                self.minValueLabel.stringValue = ""
                self.maxValueLabel.stringValue = ""
                self.currentValueLabel.stringValue = ""
                self.valueSlider.minValue = 0
                self.valueSlider.maxValue = 0
                self.changeValue(0)
            }
        }
    }
    
    @IBAction func onChangeSlider(_ sender: NSSlider) {
        self.changeValue(sender.floatValue)
        self.onChangeSliderCallBack?(self)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.step = 0
        self.valueSlider.isContinuous = false
    }
    
    private func changeValue(_ value: Float) {
        if self.step != 0 {
            let newStep = Float(self.step)
            let newValue = round(value / newStep) * newStep
            if newValue != self.valueSlider.floatValue {
                self.valueSlider.floatValue = newValue
            }
        } else {
            if self.valueSlider.floatValue != value {
                self.valueSlider.floatValue = value
            }
        }
    }
    
}
