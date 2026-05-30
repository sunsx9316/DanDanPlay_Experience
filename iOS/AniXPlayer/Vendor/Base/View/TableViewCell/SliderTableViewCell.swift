//
//  SliderTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/20.
//

import UIKit
import SnapKit

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

    lazy var titleLabel: Label = {
        let label = Label()
        return label
    }()

    lazy var minValueLabel: Label = {
        let label = Label()
        return label
    }()

    lazy var maxValueLabel: Label = {
        let label = Label()
        label.textAlignment = .right
        return label
    }()

    lazy var currentValueLabel: Label = {
        let label = Label()
        return label
    }()

    lazy var valueSlider: UISlider = {
        let slider = UISlider()
        slider.isContinuous = false
        return slider
    }()

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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(currentValueLabel)
        contentView.addSubview(minValueLabel)
        contentView.addSubview(valueSlider)
        contentView.addSubview(maxValueLabel)

        valueSlider.addTarget(self, action: #selector(onChangeSlider(_:)), for: .valueChanged)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(15)
        }

        currentValueLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.leading.equalTo(titleLabel.snp.trailing).offset(10)
        }

        minValueLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15)
            make.leading.equalToSuperview().offset(15)
            make.bottom.equalToSuperview().offset(-15)
            make.width.greaterThanOrEqualTo(40)
        }

        valueSlider.snp.makeConstraints { make in
            make.centerY.equalTo(minValueLabel)
            make.leading.equalTo(minValueLabel.snp.trailing).offset(5)
        }

        maxValueLabel.snp.makeConstraints { make in
            make.centerY.equalTo(minValueLabel)
            make.leading.equalTo(valueSlider.snp.trailing).offset(5)
            make.trailing.equalToSuperview().offset(-15)
            make.width.greaterThanOrEqualTo(40)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onChangeSlider(_ sender: UISlider) {
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
