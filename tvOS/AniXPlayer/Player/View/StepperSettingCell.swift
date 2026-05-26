//
//  StepperSettingCell.swift
//  AniXPlayer
//
//  tvOS 数值调整 Cell — 焦点时按左/右方向键递减/递增值
//  视觉参考 iOS SliderTableViewCell，自动适配浅色/深色模式
//

import UIKit
import SnapKit

class StepperSettingCell: TableViewCell {

    static let reuseIdentifier = "StepperSettingCell"

    var onValueChanged: ((Double) -> Void)?

    private var currentValue: Double = 0
    private var minValue: Double = 0
    private var maxValue: Double = 100
    private var step: Double = 1
    private var formatter: (Double) -> String = { String(format: "%.0f", $0) }

    // MARK: - UI

    private lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_small(weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private lazy var valueLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()

    private lazy var trackView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        view.layer.cornerRadius = 2
        return view
    }()

    private lazy var progressView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.mainColor
        view.layer.cornerRadius = 2
        return view
    }()

    private lazy var minusIndicator: UILabel = {
        let label = UILabel()
        label.text = "−"
        label.font = .ddp_normal(weight: .medium)
        label.textColor = UIColor.mainColor
        label.textAlignment = .center
        label.alpha = 0
        return label
    }()

    private lazy var plusIndicator: UILabel = {
        let label = UILabel()
        label.text = "+"
        label.font = .ddp_normal(weight: .medium)
        label.textColor = UIColor.mainColor
        label.textAlignment = .center
        label.alpha = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(trackView)
        trackView.addSubview(progressView)
        contentView.addSubview(minusIndicator)
        contentView.addSubview(plusIndicator)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(14)
        }

        valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(titleLabel)
            make.width.greaterThanOrEqualTo(50)
        }

        trackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.height.equalTo(3)
        }

        progressView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(0)
        }

        minusIndicator.snp.makeConstraints { make in
            make.trailing.equalTo(contentView.snp.centerX).offset(-16)
            make.top.equalTo(trackView.snp.bottom).offset(4)
            make.width.height.equalTo(36)
            make.bottom.equalToSuperview().offset(-14)
        }

        plusIndicator.snp.makeConstraints { make in
            make.leading.equalTo(contentView.snp.centerX).offset(16)
            make.centerY.equalTo(minusIndicator)
            make.width.height.equalTo(36)
        }
    }

    func configure(title: String, value: Double, min: Double, max: Double, step: Double, formatter: ((Double) -> String)? = nil) {
        titleLabel.text = title
        self.currentValue = value
        self.minValue = min
        self.maxValue = max
        self.step = step
        self.formatter = formatter ?? { String(format: "%.0f", $0) }
        updateDisplay()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        let isFocused = context.nextFocusedView === self
        coordinator.addCoordinatedAnimations {
            self.minusIndicator.alpha = isFocused ? 1 : 0
            self.plusIndicator.alpha = isFocused ? 1 : 0
            self.progressView.backgroundColor = isFocused ? .label : UIColor.mainColor
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else {
            super.pressesBegan(presses, with: event)
            return
        }

        switch press.type {
        case .leftArrow:
            let newValue = max(minValue, currentValue - step)
            if newValue != currentValue {
                currentValue = newValue
                updateDisplay()
                onValueChanged?(currentValue)
            }
        case .rightArrow:
            let newValue = min(maxValue, currentValue + step)
            if newValue != currentValue {
                currentValue = newValue
                updateDisplay()
                onValueChanged?(currentValue)
            }
        default:
            super.pressesBegan(presses, with: event)
        }
    }

    private func updateDisplay() {
        valueLabel.text = formatter(currentValue)
        updateProgress()
    }

    private func updateProgress() {
        let range = maxValue - minValue
        guard range > 0 else {
            progressView.snp.remakeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                make.width.equalTo(0)
            }
            return
        }
        let ratio = CGFloat((currentValue - minValue) / range)
        progressView.snp.remakeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(ratio)
        }
    }
}
