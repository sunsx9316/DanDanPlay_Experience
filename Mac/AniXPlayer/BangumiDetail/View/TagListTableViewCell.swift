//
//  TagListTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/10.
//

import Cocoa
import SnapKit

class TagListTableViewCell: NSTableCellView {

    private let tagSpacing: CGFloat = 8

    private var currentTags: [BangumiTag] = []

    var didTouchTagButton: ((BangumiTag) -> Void)?

    private lazy var flowStackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = tagSpacing
        stack.alignment = .leading
        return stack
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(flowStackView)

        flowStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(15)
            make.trailing.lessThanOrEqualToSuperview().offset(-15)
            make.bottom.equalToSuperview().offset(-10)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(tags: [BangumiTag]) {
        currentTags = tags
        flowStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !tags.isEmpty else { return }

        let sortedTags = tags.sorted { $0.count > $1.count }

        var currentRowStack = createRowStack()
        var currentRowWidth: CGFloat = 0

        for (index, tag) in sortedTags.enumerated() {
            let button = createTagButton(tag: tag, index: index)
            button.layoutSubtreeIfNeeded()
            let buttonWidth = button.intrinsicContentSize.width + tagSpacing * 2

            if currentRowWidth + buttonWidth > 500, !currentRowStack.arrangedSubviews.isEmpty {
                flowStackView.addArrangedSubview(currentRowStack)
                currentRowStack = createRowStack()
                currentRowWidth = 0
            }

            currentRowStack.addArrangedSubview(button)
            currentRowWidth += buttonWidth
        }

        if !currentRowStack.arrangedSubviews.isEmpty {
            flowStackView.addArrangedSubview(currentRowStack)
        }
    }

    // MARK: Private

    private func createRowStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = tagSpacing
        stack.alignment = .centerY
        return stack
    }

    private func createTagButton(tag: BangumiTag, index: Int) -> Button {
        let button = Button()
        button.title = tag.name
        button.font = .ddp_small()
        button.contentTintColor = .mainColor
        button.bezelStyle = .inline
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.12).cgColor
        button.layer?.borderColor = NSColor.mainColor.withAlphaComponent(0.25).cgColor
        button.layer?.borderWidth = 0.5
        button.layer?.cornerRadius = 12
        button.layer?.masksToBounds = true
        button.tag = index
        button.addTarget(self, action: #selector(onTouchTagButton(_:)))
        return button
    }

    @objc private func onTouchTagButton(_ sender: Button) {
        let sortedTags = currentTags.sorted { $0.count > $1.count }
        let index = sender.tag
        guard index < sortedTags.count else { return }
        didTouchTagButton?(sortedTags[index])
    }
}
