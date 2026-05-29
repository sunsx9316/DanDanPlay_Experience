//
//  SegmentBar.swift
//  AniXPlayer
//
//  自定义分段控件，替代 JXCategoryTitleView
//

import UIKit
import SnapKit

class TimelineSegmentBar: UIView {

    var titles: [String] = [] {
        didSet { reloadTitles() }
    }

    var selectedIndex: Int = 0 {
        didSet {
            guard selectedIndex != oldValue else { return }
            updateSelection()
        }
    }

    var onSelected: ((Int) -> Void)?

    var titleFont: UIFont = .ddp_normal
    var titleSelectedFont: UIFont = .ddp_large
    var titleColor: UIColor = .textColor
    var titleSelectedColor: UIColor = .mainColor
    var indicatorColor: UIColor = .mainColor {
        didSet { indicatorView.backgroundColor = indicatorColor }
    }
    var indicatorHeight: CGFloat = 2 {
        didSet {
            indicatorView.snp.updateConstraints { make in
                make.height.equalTo(indicatorHeight)
            }
        }
    }

    // MARK: - Private

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        return sv
    }()

    private let indicatorView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 1
        return v
    }()

    private var buttons: [UIButton] = []
    private var indicatorCenterXConstraint: Constraint?
    private var indicatorWidthConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        indicatorView.backgroundColor = indicatorColor

        addSubview(stackView)
        addSubview(indicatorView)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        indicatorView.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalTo(indicatorHeight)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private Methods

    private func reloadTitles() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = []

        for (index, title) in titles.enumerated() {
            let btn = UIButton(type: .custom)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = titleFont
            btn.setTitleColor(titleColor, for: .normal)
            btn.tag = index
            btn.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(btn)
            buttons.append(btn)
        }

        updateIndicator(animated: false)
        updateButtonAppearance()
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedIndex else { return }
        onSelected?(index)
    }

    private func updateSelection() {
        updateButtonAppearance()
        updateIndicator(animated: true)
    }

    private func updateButtonAppearance() {
        for (i, btn) in buttons.enumerated() {
            let isSelected = i == selectedIndex
            btn.setTitleColor(isSelected ? titleSelectedColor : titleColor, for: .normal)
            btn.titleLabel?.font = isSelected ? titleSelectedFont : titleFont
        }
    }

    private func updateIndicator(animated: Bool) {
        guard selectedIndex < buttons.count else { return }
        let targetButton = buttons[selectedIndex]

        let animations = { [weak self] in
            guard let self = self else { return }
            self.indicatorView.snp.remakeConstraints { make in
                make.bottom.equalToSuperview()
                make.height.equalTo(self.indicatorHeight)
                make.centerX.equalTo(targetButton)
                make.width.equalTo(targetButton.snp.width).multipliedBy(0.6)
            }
            self.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: animations)
        } else {
            animations()
        }
    }
}
