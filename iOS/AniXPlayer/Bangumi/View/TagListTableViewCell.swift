//
//  TagListTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/8.
//

import UIKit
import SnapKit

class TagListTableViewCell: TableViewCell {

    private enum Layout {
        static let contentInsets = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        static let spacing: CGFloat = 8
    }

    private let flowView = TagFlowView()

    var didTouchTagButton: ((BangumiTag) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.layoutMargins = Layout.contentInsets
        contentView.addSubview(flowView)
        flowView.snp.makeConstraints { make in
            make.edges.equalTo(contentView.layoutMarginsGuide)
        }

        flowView.metrics = .init(horizontalSpacing: Layout.spacing, verticalSpacing: Layout.spacing)
        flowView.configureButton = { button, tag in
            button.setTitle(tag.name, for: .normal)
            button.titleLabel?.font = .ddp_small
            button.setTitleColor(.mainColor, for: .normal)
            button.backgroundColor = UIColor.mainColor.withAlphaComponent(0.12)
            button.layer.borderColor = UIColor.mainColor.withAlphaComponent(0.25).cgColor
            button.layer.borderWidth = 0.5
            button.layer.cornerRadius = 12
            button.layer.masksToBounds = true
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
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

        let margins = contentView.layoutMargins
        let contentWidth = TagCellLayout.contentWidth(
            targetWidth: targetSize.width,
            contentViewWidth: contentView.bounds.width,
            leftMargin: margins.left,
            rightMargin: margins.right
        )
        let height = flowView.heightThatFits(width: contentWidth) + margins.top + margins.bottom
        return CGSize(width: targetSize.width, height: height)
    }
}
