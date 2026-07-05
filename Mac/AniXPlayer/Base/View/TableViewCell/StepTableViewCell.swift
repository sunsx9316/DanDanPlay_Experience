//
//  StepTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa
import SnapKit

class StepTableViewCell: NSView {

    lazy var titleLabel = Label()

    lazy var stepper = NSStepper()

    lazy var valueLabel = Label()

    var onTouchStepperCallBack: ((StepTableViewCell) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(stepper)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
        }
        stepper.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }
        valueLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(10)
            make.centerY.equalTo(titleLabel)
            make.trailing.equalTo(stepper.snp.leading).offset(-10)
        }
        stepper.addTarget(self, action: #selector(onTouchStepper(_:)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc private func onTouchStepper(_ sender: NSStepper) {
        onTouchStepperCallBack?(self)
    }
}
