//
//  SliderTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa
import SnapKit

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

    lazy var titleLabel = Label()

    lazy var currentValueLabel = Label()

    lazy var minValueLabel = Label()

    lazy var maxValueLabel = Label()

    lazy var valueSlider = Slider()

    /// 步长
    var step: Float = 0

    var onChangeSliderCallBack: ((SliderTableViewCell) -> Void)?

    var model: Model? {
        didSet {
            if let model = self.model {
                minValueLabel.text = model.minValueFormattingCallBack?(model) ?? ""
                maxValueLabel.text = model.maxValueFormattingCallBack?(model) ?? ""
                currentValueLabel.text = model.currentValueFormattingCallBack?(model) ?? ""
                valueSlider.minValue = Double(model.minValue)
                valueSlider.maxValue = Double(model.maxValue)
                changeValue(model.currentValue)
            } else {
                minValueLabel.text = ""
                maxValueLabel.text = ""
                currentValueLabel.text = ""
                valueSlider.minValue = 0
                valueSlider.maxValue = 0
                changeValue(0)
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleLabel)
        addSubview(currentValueLabel)
        addSubview(minValueLabel)
        addSubview(valueSlider)
        addSubview(maxValueLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(10)
        }
        currentValueLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(10)
            make.centerY.equalTo(titleLabel)
        }
        minValueLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
        }
        valueSlider.snp.makeConstraints { make in
            make.leading.equalTo(minValueLabel.snp.trailing).offset(10)
            make.centerY.equalTo(minValueLabel)
        }
        maxValueLabel.snp.makeConstraints { make in
            make.leading.equalTo(valueSlider.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(minValueLabel)
        }
        valueSlider.addTarget(self, action: #selector(onChangeSlider(_:)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        step = 0
        valueSlider.isContinuous = false
    }

    @objc private func onChangeSlider(_ sender: NSSlider) {
        changeValue(sender.floatValue)
        onChangeSliderCallBack?(self)
    }

    private func changeValue(_ value: Float) {
        if step != 0 {
            let newStep = Float(step)
            let newValue = round(value / newStep) * newStep
            if newValue != valueSlider.floatValue {
                valueSlider.floatValue = newValue
            }
        } else {
            if valueSlider.floatValue != value {
                valueSlider.floatValue = value
            }
        }
    }
}
