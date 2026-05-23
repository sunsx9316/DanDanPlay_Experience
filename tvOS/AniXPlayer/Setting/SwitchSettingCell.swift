//
//  SwitchSettingCell.swift
//  AniXPlayer
//
//  tvOS 开关设置 Cell — 点按 Select 切换，自动适配浅色/深色模式
//

import UIKit
import SnapKit

class SwitchSettingCell: TableViewCell {

    static let reuseIdentifier = "SwitchSettingCell"

    var onSwitchChanged: ((Bool) -> Void)?

    private var isSwitchOn = false

    // MARK: - UI

    private lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_small(weight: .medium)
        label.textColor = .label
        return label
    }()

    private lazy var togglePill: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 2
        return view
    }()

    private lazy var toggleKnob: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 10
        return view
    }()

    private lazy var stateLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
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
        contentView.addSubview(stateLabel)
        contentView.addSubview(togglePill)
        togglePill.addSubview(toggleKnob)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }

        togglePill.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-40)
            make.centerY.equalToSuperview()
            make.width.equalTo(48)
            make.height.equalTo(28)
        }

        toggleKnob.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 20, height: 20))
        }

        stateLabel.snp.makeConstraints { make in
            make.trailing.equalTo(togglePill.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    func configure(title: String, isOn: Bool) {
        titleLabel.text = title
        self.isSwitchOn = isOn
        updateToggleAppearance(animated: false)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)

        guard let press = presses.first, press.type == .select else { return }

        isSwitchOn.toggle()
        updateToggleAppearance(animated: true)
        onSwitchChanged?(isSwitchOn)
    }

    private func updateToggleAppearance(animated: Bool) {
        let bgColor: UIColor = isSwitchOn ? UIColor.mainColor : .adaptiveSecondaryBackground
        let knobOffset = isSwitchOn ? 22 : 2
        let pillBorderColor: UIColor = isSwitchOn ? UIColor.mainColor : .separator
        stateLabel.text = isSwitchOn ? NSLocalizedString("开", comment: "") : NSLocalizedString("关", comment: "")

        let changes = {
            self.togglePill.backgroundColor = bgColor
            self.togglePill.layer.borderColor = pillBorderColor.cgColor
            self.toggleKnob.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(knobOffset)
                make.centerY.equalToSuperview()
                make.size.equalTo(CGSize(width: 20, height: 20))
            }
            self.togglePill.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: changes)
        } else {
            changes()
        }
    }
}
