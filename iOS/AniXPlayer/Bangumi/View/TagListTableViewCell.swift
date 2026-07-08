//
//  TagListTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/8.
//

import UIKit

class TagListTableViewCell: TableViewCell {

    private let tagSpacing: CGFloat = 8

    private lazy var flowStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = tagSpacing
        stack.alignment = .leading
        return stack
    }()

    private var currentTags: [BangumiTag] = []

    var didTouchTagButton: ((BangumiTag) -> Void)?

    func update(tags: [BangumiTag]) {
        currentTags = tags
        flowStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !tags.isEmpty else { return }

        let sortedTags = tags.sorted { $0.count > $1.count }
        let maxWidth = UIScreen.main.bounds.width - 30

        var currentRowStack = createRowStack()
        var currentRowWidth: CGFloat = 0

        for (index, tag) in sortedTags.enumerated() {
            let button = createTagButton(tag: tag, index: index)
            let buttonWidth = button.intrinsicContentSize.width + tagSpacing

            if currentRowWidth + buttonWidth > maxWidth, !(currentRowStack.arrangedSubviews.isEmpty) {
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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(flowStackView)

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

    // MARK: Private

    private func createRowStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = tagSpacing
        stack.alignment = .center
        return stack
    }

    private func createTagButton(tag: BangumiTag, index: Int) -> Button {
        let button = Button()
        button.setTitle(tag.name, for: .normal)
        button.titleLabel?.font = .ddp_small
        button.setTitleColor(.mainColor, for: .normal)
        button.backgroundColor = UIColor.mainColor.withAlphaComponent(0.12)
        button.layer.borderColor = UIColor.mainColor.withAlphaComponent(0.25).cgColor
        button.layer.borderWidth = 0.5
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        button.tag = index
        button.addTarget(self, action: #selector(onTouchTagButton(_:)), for: .touchUpInside)
        return button
    }

    @objc private func onTouchTagButton(_ sender: Button) {
        let sortedTags = currentTags.sorted { $0.count > $1.count }
        let index = sender.tag
        guard index < sortedTags.count else { return }
        didTouchTagButton?(sortedTags[index])
    }
}
