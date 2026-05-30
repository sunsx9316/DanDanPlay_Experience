//
//  StepTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/22.
//

import UIKit
import SnapKit

class StepTableViewCell: TableViewCell {

    lazy var titleLabel: Label = {
        let label = Label()
        return label
    }()

    lazy var valueLabel: Label = {
        let label = Label()
        return label
    }()

    lazy var stepper: UIStepper = {
        let stepper = UIStepper()
        return stepper
    }()

    var onTouchStepperCallBack: ((StepTableViewCell) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(stepper)

        stepper.addTarget(self, action: #selector(onTouchStepper(_:)), for: .valueChanged)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
        }

        stepper.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(titleLabel)
            make.top.equalToSuperview().offset(6)
            make.bottom.equalToSuperview().offset(-6)
        }

        valueLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.trailing.equalTo(stepper.snp.leading).offset(-10)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onTouchStepper(_ sender: UIStepper) {
        self.onTouchStepperCallBack?(self)
    }
}
