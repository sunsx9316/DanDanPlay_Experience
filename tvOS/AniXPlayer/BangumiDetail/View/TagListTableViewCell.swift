//
//  TagListTableViewCell.swift
//  AniXPlayer
//
//  tvOS 番剧标签列表 Cell — 流式布局 + Focus Engine 适配
//

import UIKit
import SnapKit

class TagListTableViewCell: TableViewCell {

    private static let horizontalInset: CGFloat = 60
    private static let verticalInset: CGFloat = 16

    private let flowView = TagFlowView()

    var didTouchTagButton: ((BangumiTag) -> Void)?

    override var canBecomeFocused: Bool { return false }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [flowView]
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(flowView)
        flowView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.verticalInset)
            make.leading.equalToSuperview().offset(Self.horizontalInset)
            make.trailing.equalToSuperview().offset(-Self.horizontalInset)
            make.bottom.equalToSuperview().offset(-Self.verticalInset)
        }

        flowView.metrics = .init(horizontalSpacing: 12, verticalSpacing: 12)
        flowView.configureButton = { button, tag in
            button.setTitle(tag.name, for: .normal)
            button.titleLabel?.font = .ddp_small()
            button.setTitleColor(.mainColor, for: .normal)
            button.backgroundColor = UIColor.mainColor.withAlphaComponent(0.12)
            button.layer.borderColor = UIColor.mainColor.withAlphaComponent(0.25).cgColor
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 16
            button.layer.masksToBounds = true
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        }
        flowView.onTagTap = { [weak self] tag in
            self?.didTouchTagButton?(tag)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(tags: [BangumiTag]) {
        flowView.update(tags: tags.sorted { $0.count > $1.count })
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        guard targetSize.width > 0, targetSize.width < .greatestFiniteMagnitude else {
            return super.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: horizontalFittingPriority,
                verticalFittingPriority: verticalFittingPriority
            )
        }

        let contentWidth = targetSize.width - Self.horizontalInset * 2
        let height = flowView.heightThatFits(width: contentWidth) + Self.verticalInset * 2
        return CGSize(width: targetSize.width, height: height)
    }
}
