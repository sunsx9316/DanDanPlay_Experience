//
//  HomePageFunctionTableViewCell.swift
//  AniXPlayer
//
//  tvOS 首页功能区
//

import UIKit
import SnapKit

class HomePageFunctionTableViewCell: TableViewCell {
    
    private class SelectedButton: Button {
        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            coordinator.addCoordinatedAnimations({
                if self.isFocused {
                    self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                    self.backgroundColor = UIColor.mainColor
                } else {
                    self.transform = .identity
                    self.backgroundColor = UIColor.adaptiveSecondaryBackground
                }
            })
        }
    }
    

    enum ItemType {
        case timeline
        case favorite
    }

    var onItemSelected: ((ItemType) -> Void)?

    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 2
        sv.alignment = .center
        sv.distribution = .fillEqually
        sv.clipsToBounds = true
        sv.layer.cornerRadius = 8
        return sv
    }()

    private lazy var timelineButton: Button = {
        let btn = SelectedButton()
        btn.setTitle(NSLocalizedString("新番时间表", comment: ""), for: .normal)
        btn.setTitleColor(.adaptiveText, for: .normal)
        btn.titleLabel?.font = .ddp_small(weight: .medium)
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        btn.addTarget(self, action: #selector(timelineTapped), for: .primaryActionTriggered)
        btn.setBackgroundImage(UIImage.init(color: .mainColor), for: .focused)
        btn.setBackgroundImage(UIImage.init(color: .adaptiveSecondaryBackground), for: .normal)
        return btn
    }()

    private lazy var favoriteButton: Button = {
        let btn = SelectedButton()
        btn.setTitle(NSLocalizedString("我的关注", comment: ""), for: .normal)
        btn.setTitleColor(.adaptiveText, for: .normal)
        btn.titleLabel?.font = .ddp_small(weight: .medium)
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        btn.addTarget(self, action: #selector(favoriteTapped), for: .primaryActionTriggered)
        btn.setBackgroundImage(UIImage.init(color: .mainColor), for: .focused)
        btn.setBackgroundImage(UIImage.init(color: .adaptiveSecondaryBackground), for: .normal)
        return btn
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override var canBecomeFocused: Bool { return false }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [timelineButton, favoriteButton]
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        reloadButtons()
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(stackView)
        stackView.addArrangedSubview(timelineButton)
        stackView.addArrangedSubview(favoriteButton)

        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        reloadButtons()
    }

    @objc private func reloadButtons() {
        favoriteButton.isHidden = Preferences.shared.loginInfo == nil
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
