//
//  TagListTableViewCell.swift
//  AniXPlayer
//
//  tvOS 番剧标签列表 Cell — 流式布局 + Focus Engine 适配
//

import UIKit

class TagListTableViewCell: TableViewCell {

    private let tagSpacing: CGFloat = 12

    private lazy var flowStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = tagSpacing
        stack.alignment = .leading
        return stack
    }()

    private var currentTags: [BangumiTag] = []

    var didTouchTagButton: ((BangumiTag) -> Void)?

    override var canBecomeFocused: Bool { return false }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return currentTags.isEmpty ? [] : [flowStackView]
    }

    func update(tags: [BangumiTag]) {
        currentTags = tags
        flowStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !tags.isEmpty else { return }

        let sortedTags = tags.sorted { $0.count > $1.count }
        let maxWidth = UIScreen.main.bounds.width - 120

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
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(60)
            make.trailing.lessThanOrEqualToSuperview().offset(-60)
            make.bottom.equalToSuperview().offset(-16)
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
        button.titleLabel?.font = .ddp_small()
        button.setTitleColor(.mainColor, for: .normal)
        button.backgroundColor = UIColor.mainColor.withAlphaComponent(0.12)
        button.layer.borderColor = UIColor.mainColor.withAlphaComponent(0.25).cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        button.tag = index
        button.addTarget(self, action: #selector(onTouchTagButton(_:)), for: .primaryActionTriggered)
        return button
    }

    @objc private func onTouchTagButton(_ sender: Button) {
        let sortedTags = currentTags.sorted { $0.count > $1.count }
        let index = sender.tag
        guard index < sortedTags.count else { return }
        didTouchTagButton?(sortedTags[index])
    }
}
