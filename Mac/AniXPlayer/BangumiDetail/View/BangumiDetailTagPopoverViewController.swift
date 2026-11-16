//
//  BangumiDetailTagPopoverViewController.swift
//  AniXPlayer
//
//  macOS：详情页「+N」展开的完整标签列表。
//

import Cocoa
import SnapKit

final class BangumiDetailTagPopoverViewController: NSViewController {

    private let tags: [BangumiTag]
    private let contentView = WelcomeShellFlippedView()
    private let stackView = NSStackView()

    init(tags: [BangumiTag]) {
        self.tags = tags
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.count > $1.count }
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 300, height: 360)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: preferredContentSize))
        view.setAccessibilityIdentifier("\(AccessibilityID.BangumiDetail.heroTags).popover")

        contentView.frame = NSRect(origin: .zero, size: preferredContentSize)
        stackView.orientation = .vertical
        stackView.alignment = .width
        stackView.spacing = 4

        let title = welcomeShellLabel(
            NSLocalizedString("全部标签", comment: ""),
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor
        )
        stackView.addArrangedSubview(title)
        stackView.setCustomSpacing(10, after: title)

        if tags.isEmpty {
            let empty = welcomeShellLabel(
                NSLocalizedString("暂无标签", comment: ""),
                font: .systemFont(ofSize: 12),
                color: .secondaryLabelColor
            )
            stackView.addArrangedSubview(empty)
        } else {
            for tag in tags {
                stackView.addArrangedSubview(makeRow(for: tag))
            }
        }

        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().offset(-14)
            make.bottom.equalToSuperview().offset(-14)
        }

        let scrollView = ScrollView<WelcomeShellFlippedView>(containerView: contentView)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let width = view.bounds.width
        guard width > 0 else { return }
        stackView.layoutSubtreeIfNeeded()
        let height = max(view.bounds.height, stackView.fittingSize.height + 28)
        let target = NSRect(x: 0, y: 0, width: width, height: height)
        if contentView.frame != target {
            contentView.frame = target
        }
    }

    private func makeRow(for tag: BangumiTag) -> NSView {
        let name = welcomeShellLabel(
            tag.name,
            font: .systemFont(ofSize: 12.5),
            color: .labelColor
        )
        let count = welcomeShellLabel(
            "\(tag.count)",
            font: .systemFont(ofSize: 11),
            color: .secondaryLabelColor,
            alignment: .right
        )
        count.setContentHuggingPriority(.required, for: .horizontal)

        let row = NSStackView(views: [name, count])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
        return row
    }
}
