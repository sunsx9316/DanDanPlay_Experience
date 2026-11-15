//
//  TagFlowView.swift
//  CocoaShare
//
//  可复用的标签流式视图：按钮只创建一次，宽度变化时只重新布局。
//

#if os(iOS) || os(tvOS)
import UIKit

final class TagFlowButton: UIButton {
    var bangumiTag: BangumiTag?
}

final class TagFlowView: UIView {

    struct Metrics {
        var horizontalSpacing: CGFloat
        var verticalSpacing: CGFloat
    }

    var metrics = Metrics(horizontalSpacing: 8, verticalSpacing: 8) {
        didSet {
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    var onTagTap: ((BangumiTag) -> Void)?
    var configureButton: ((TagFlowButton, BangumiTag) -> Void)?

    private(set) var buttons: [TagFlowButton] = []
    private var currentTags: [BangumiTag] = []
    private var lastContentHeight: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(tags: [BangumiTag]) {
        guard tags.map(\.name) != currentTags.map(\.name) else { return }

        currentTags = tags

        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll(keepingCapacity: true)

        guard !tags.isEmpty else {
            lastContentHeight = 0
            invalidateIntrinsicContentSize()
            setNeedsLayout()
            return
        }

        for tag in tags {
            let button = TagFlowButton(type: .custom)
            button.bangumiTag = tag
            configureButton?(button, tag)
            #if os(tvOS)
            button.addTarget(self, action: #selector(onTap(_:)), for: .primaryActionTriggered)
            #else
            button.addTarget(self, action: #selector(onTap(_:)), for: .touchUpInside)
            #endif
            addSubview(button)
            buttons.append(button)
        }

        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    func heightThatFits(width: CGFloat) -> CGFloat {
        guard width > 0, !buttons.isEmpty else { return 0 }

        let result = TagFlowLayout.layout(
            sizes: buttonSizes,
            in: width,
            metrics: layoutMetrics,
            layoutDirection: layoutDirection
        )
        return result.contentHeight
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard !buttons.isEmpty else {
            if lastContentHeight != 0 {
                lastContentHeight = 0
                invalidateIntrinsicContentSize()
            }
            return
        }

        let result = TagFlowLayout.layout(
            sizes: buttonSizes,
            in: bounds.width,
            metrics: layoutMetrics,
            layoutDirection: layoutDirection
        )

        for (index, frame) in result.frames.enumerated() where index < buttons.count {
            buttons[index].frame = frame
        }

        if abs(result.contentHeight - lastContentHeight) > 0.001 {
            lastContentHeight = result.contentHeight
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: lastContentHeight)
    }

    #if os(tvOS)
    override var canBecomeFocused: Bool { false }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        buttons.map { $0 as UIFocusEnvironment }
    }
    #endif

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if #available(iOS 17.0, tvOS 17.0, *) { return }

        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    // MARK: - Private

    private var layoutMetrics: TagFlowLayout.Metrics {
        .init(horizontalSpacing: metrics.horizontalSpacing, verticalSpacing: metrics.verticalSpacing)
    }

    private var layoutDirection: TagFlowLayout.LayoutDirection {
        effectiveUserInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    private var buttonSizes: [CGSize] {
        buttons.map {
            $0.sizeThatFits(
                CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            )
        }
    }

    private func setup() {
        if #available(iOS 17.0, tvOS 17.0, *) {
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: TagFlowView, _) in
                self.setNeedsLayout()
                self.invalidateIntrinsicContentSize()
            }
        }
    }

    @objc private func onTap(_ sender: UIButton) {
        guard let button = sender as? TagFlowButton,
              let tag = button.bangumiTag else { return }
        onTagTap?(tag)
    }
}
#endif
