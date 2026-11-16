//
//  BangumiDetailTagFlowView.swift
//  AniXPlayer
//
//  macOS：详情页的标签胶囊，最多显示两行，超出时出现「+N」。
//

import Cocoa
import SnapKit

final class BangumiDetailTagChipButton: Button {

    private let chipFont = NSFont.systemFont(ofSize: 11.5, weight: .medium)
    private let horizontalPadding: CGFloat = 8
    private let chipHeight: CGFloat = 22

    init(title: String, emphasized: Bool) {
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        bezelStyle = .inline
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = chipHeight / 2
        layer?.borderWidth = 0.5
        layer?.masksToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        applyTitle(title, emphasized: emphasized)
        updateColors(emphasized: emphasized)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let width = (title as NSString).size(withAttributes: [.font: chipFont]).width
        return NSSize(width: ceil(width) + horizontalPadding * 2, height: chipHeight)
    }

    func update(title: String, emphasized: Bool) {
        self.title = title
        applyTitle(title, emphasized: emphasized)
        updateColors(emphasized: emphasized)
        invalidateIntrinsicContentSize()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors(emphasized: (title as NSString).hasPrefix("+"))
    }

    private func applyTitle(_ title: String, emphasized: Bool) {
        let color = emphasized ? NSColor.mainColor : NSColor.mainColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: chipFont,
                .foregroundColor: color
            ]
        )
        setAccessibilityLabel(title)
    }

    private func updateColors(emphasized: Bool) {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            guard let self = self else { return }
            let base = emphasized
                ? NSColor.mainColor.withAlphaComponent(0.14)
                : NSColor.mainColor.withAlphaComponent(0.08)
            self.layer?.backgroundColor = base.cgColor
            self.layer?.borderColor = NSColor.mainColor.withAlphaComponent(0.22).cgColor
        }
    }
}

final class BangumiDetailTagFlowView: NSView {

    private enum Layout {
        static let chipHeight: CGFloat = 22
        static let chipSpacing: CGFloat = 6
        static let rowSpacing: CGFloat = 6
        static let maximumRows = 2
    }

    var onMore: ((NSView) -> Void)?
    var onHeightChange: (() -> Void)?

    private var chips: [BangumiDetailTagChipButton] = []
    private let moreChip = BangumiDetailTagChipButton(title: "+0", emphasized: true)
    private var heightConstraint: Constraint?
    private var lastHeight: CGFloat = -1
    private var isLayingOut = false

    override var isFlipped: Bool {
        return true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(tagNames: [String]) {
        chips.forEach { $0.removeFromSuperview() }
        chips = tagNames.enumerated().map { index, name in
            let chip = BangumiDetailTagChipButton(title: name, emphasized: false)
            chip.setAccessibilityIdentifier("\(AccessibilityID.BangumiDetail.tagPrefix)\(index)")
            addSubview(chip)
            return chip
        }
        moreChip.isHidden = true
        isHidden = tagNames.isEmpty
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    override func layout() {
        super.layout()
        guard !isLayingOut else { return }
        isLayingOut = true
        defer { isLayingOut = false }
        layoutChips(width: bounds.width)
    }

    private func setup() {
        addSubview(moreChip)
        moreChip.addTarget(self, action: #selector(moreClicked))
        moreChip.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.tagsMore)
        moreChip.isHidden = true
        snp.makeConstraints { make in
            heightConstraint = make.height.equalTo(0).constraint
        }
    }

    private func layoutChips(width: CGFloat) {
        guard width > 0 else { return }
        guard !chips.isEmpty else {
            updateHeight(0)
            return
        }

        let widths = chips.map { min($0.intrinsicContentSize.width, width) }
        // 用最大可能的「+N」宽度测一次，避免两位数时胶囊裁字。
        let maximumMoreTitle = "+\(chips.count)"
        if moreChip.title != maximumMoreTitle {
            moreChip.update(title: maximumMoreTitle, emphasized: true)
        }
        let moreWidth = min(moreChip.intrinsicContentSize.width, width)

        let all = placement(
            count: chips.count,
            widths: widths,
            moreWidth: moreWidth,
            availableWidth: width,
            reserveMore: false
        )
        if !all.overflow {
            apply(frames: all.frames, visibleCount: chips.count, rows: all.rows, moreCount: 0)
            return
        }

        for count in stride(from: chips.count - 1, through: 0, by: -1) {
            let result = placement(
                count: count,
                widths: widths,
                moreWidth: moreWidth,
                availableWidth: width,
                reserveMore: true
            )
            guard !result.overflow else { continue }
            apply(
                frames: result.frames,
                visibleCount: count,
                rows: result.rows,
                moreCount: chips.count - count
            )
            return
        }

        // 极端窄宽度下至少保留「+N」。
        chips.forEach { $0.isHidden = true }
        if moreChip.title != "+\(chips.count)" {
            moreChip.update(
                title: "+\(chips.count)",
                emphasized: true
            )
        }
        moreChip.setAccessibilityLabel(String(
            format: NSLocalizedString("还有 %d 个标签", comment: ""),
            chips.count
        ))
        moreChip.frame = NSRect(x: 0, y: 0, width: min(moreWidth, width), height: Layout.chipHeight)
        moreChip.isHidden = false
        updateHeight(Layout.chipHeight)
    }

    private func placement(
        count: Int,
        widths: [CGFloat],
        moreWidth: CGFloat,
        availableWidth: CGFloat,
        reserveMore: Bool
    ) -> (frames: [NSRect], rows: Int, overflow: Bool) {
        var frames: [NSRect] = []
        var row = 0
        var x: CGFloat = 0

        for index in 0..<count {
            let width = widths[index]
            if x > 0, x + width > availableWidth {
                row += 1
                x = 0
            }
            guard row < Layout.maximumRows else {
                return (frames, Layout.maximumRows, true)
            }
            let y = CGFloat(row) * (Layout.chipHeight + Layout.rowSpacing)
            frames.append(NSRect(x: x, y: y, width: width, height: Layout.chipHeight))
            x += width + Layout.chipSpacing
        }

        guard reserveMore else {
            return (frames, row + 1, false)
        }

        if x > 0, x + moreWidth > availableWidth {
            row += 1
            x = 0
        }
        guard row < Layout.maximumRows else {
            return (frames, Layout.maximumRows, true)
        }
        let y = CGFloat(row) * (Layout.chipHeight + Layout.rowSpacing)
        frames.append(NSRect(x: x, y: y, width: moreWidth, height: Layout.chipHeight))
        return (frames, row + 1, false)
    }

    private func apply(frames: [NSRect], visibleCount: Int, rows: Int, moreCount: Int) {
        for (index, chip) in chips.enumerated() {
            chip.isHidden = index >= visibleCount
            guard index < visibleCount, index < frames.count else { continue }
            chip.frame = frames[index]
        }

        if moreCount > 0, frames.count > visibleCount {
            if moreChip.title != "+\(moreCount)" {
                moreChip.update(
                    title: "+\(moreCount)",
                    emphasized: true
                )
            }
            moreChip.setAccessibilityLabel(String(
                format: NSLocalizedString("还有 %d 个标签", comment: ""),
                moreCount
            ))
            moreChip.frame = frames[visibleCount]
            moreChip.isHidden = false
        } else {
            moreChip.isHidden = true
        }

        let height = CGFloat(rows) * Layout.chipHeight
            + CGFloat(max(0, rows - 1)) * Layout.rowSpacing
        updateHeight(height)
    }

    private func updateHeight(_ height: CGFloat) {
        guard abs(lastHeight - height) > 0.5 else { return }
        lastHeight = height
        heightConstraint?.update(offset: height)
        invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in
            self?.onHeightChange?()
        }
    }

    @objc private func moreClicked() {
        onMore?(moreChip)
    }
}
