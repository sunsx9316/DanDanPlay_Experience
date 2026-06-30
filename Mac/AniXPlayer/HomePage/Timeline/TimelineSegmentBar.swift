//
//  TimelineSegmentBar.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

class TimelineSegmentBar: BaseView {

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

    var titleFont: NSFont = .ddp_normal
    var titleSelectedFont: NSFont = .ddp_large
    var titleColor: NSColor = .textColor
    var titleSelectedColor: NSColor = .mainColor
    var indicatorColor: NSColor = .mainColor
    var indicatorHeight: CGFloat = 2

    // MARK: - Private

    private let stackView: NSStackView = {
        let sv = NSStackView()
        sv.orientation = .horizontal
        sv.distribution = .fillEqually
        return sv
    }()

    private lazy var indicatorView: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = indicatorColor.cgColor
        v.layer?.cornerRadius = 1
        return v
    }()

    private var buttons: [Button] = []
    private var indicatorCenterXConstraint: Constraint?
    private var indicatorWidthConstraint: Constraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

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

    // MARK: - Private

    private func reloadTitles() {
        buttons.removeAll()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, title) in titles.enumerated() {
            let btn = Button(title: title, target: self, action: #selector(buttonTapped(_:)))
            btn.tag = index
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.focusRingType = .none
            btn.font = titleFont
            btn.contentTintColor = titleColor
            stackView.addArrangedSubview(btn)
            buttons.append(btn)
        }

        updateIndicator(animated: false)
        updateButtonAppearance()
    }

    @objc private func buttonTapped(_ sender: NSButton) {
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
            btn.font = isSelected ? titleSelectedFont : titleFont
            btn.contentTintColor = isSelected ? titleSelectedColor : titleColor
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
            self.layoutSubtreeIfNeeded()
        }

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.allowsImplicitAnimation = true
                animations()
            }
        } else {
            animations()
        }
    }
}
