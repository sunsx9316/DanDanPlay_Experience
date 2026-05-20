//
//  SwitchSettingCell.swift
//  AniXPlayer
//
//  tvOS 开关设置 Cell — 点按切换状态
//

import UIKit
import SnapKit

class SwitchSettingCell: TableViewCell {

    static let reuseIdentifier = "SwitchSettingCell"

    var onSwitchChanged: ((Bool) -> Void)?

    private var isSwitchOn = false

    private let titleLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 18)
        label.textColor = .lightGray
        return label
    }()

    private let stateLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 17)
        label.textColor = .lightGray
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

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }

        stateLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
    }

    func configure(title: String, isOn: Bool) {
        titleLabel.text = title
        self.isSwitchOn = isOn
        stateLabel.text = isOn ? NSLocalizedString("开", comment: "") : NSLocalizedString("关", comment: "")
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)

        guard let press = presses.first, press.type == .select else { return }

        isSwitchOn.toggle()
        stateLabel.text = isSwitchOn ? NSLocalizedString("开", comment: "") : NSLocalizedString("关", comment: "")
        onSwitchChanged?(isSwitchOn)
    }
}
