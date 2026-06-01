//
//  HomePageFunctionCell.swift
//  AniXPlayer
//
//  tvOS 首页功能区 — 参考 iOS HomePageFunctionTableViewCell，Timeline + 登录后Favorites
//

import UIKit
import SnapKit

class HomePageFunctionCell: TableViewCell {

    enum ItemType {
        case timeline
        case favorite
    }

    static let reuseIdentifier = "HomePageFunctionCell"

    var onItemSelected: ((ItemType) -> Void)?

    private var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 30
        sv.distribution = .fillEqually
        sv.alignment = .center
        return sv
    }()

    private lazy var timelineButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(NSLocalizedString("新番时间表", comment: ""), for: .normal)
        btn.titleLabel?.font = .ddp_small(weight: .medium)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitleColor(.black, for: .focused)
        btn.addTarget(self, action: #selector(timelineTapped), for: .primaryActionTriggered)
        return btn
    }()

    private lazy var favoriteButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(NSLocalizedString("我的关注", comment: ""), for: .normal)
        btn.titleLabel?.font = .ddp_small(weight: .medium)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitleColor(.black, for: .focused)
        btn.addTarget(self, action: #selector(favoriteTapped), for: .primaryActionTriggered)
        return btn
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadButtons),
            name: .AnixUserLoginStateDidChange,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var canBecomeFocused: Bool { return false }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if Preferences.shared.loginInfo != nil {
            return [timelineButton, favoriteButton]
        }
        return [timelineButton]
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        selectionStyle = .none

        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalTo(60)
        }
        reloadButtons()
    }

    @objc private func reloadButtons() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stackView.addArrangedSubview(timelineButton)

        if Preferences.shared.loginInfo != nil {
            stackView.addArrangedSubview(favoriteButton)
        }
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }

    @objc private func timelineTapped() {
        onItemSelected?(.timeline)
    }

    @objc private func favoriteTapped() {
        onItemSelected?(.favorite)
    }
}
