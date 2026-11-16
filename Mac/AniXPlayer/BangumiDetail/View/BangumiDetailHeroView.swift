//
//  BangumiDetailHeroView.swift
//  AniXPlayer
//
//  macOS：番剧详情的头图、标题、评分、标签、简介和操作区。
//

import Cocoa
import SnapKit
import Kingfisher

final class BangumiDetailHeroView: BangumiDetailCardView {

    var onFavoriteToggle: ((Int, Bool) -> Void)?
    var onTapMetadata: (() -> Void)?
    var onTapEpisodes: (() -> Void)?
    var onLayoutChange: (() -> Void)?

    private var animeId = 0
    private var isFavorited = false
    private var detail: BangumiDetail?
    private var isSummaryExpanded = false
    private var usesCompactCover = false
    private var lastLayoutWidth: CGFloat = 0
    private var tagPopover: NSPopover?

    private let coverWrapper = NSView()
    private let coverImageView = ImageView()
    private let ratingBadge = Label(labelWithString: "")
    private let topRow = NSStackView()
    private let infoStack = NSStackView()
    private let titleLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .labelColor
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.cell?.wraps = true
        return label
    }()
    private let originalTitleLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    private let ratingSourceLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    private let metaLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    private let tagFlow = BangumiDetailTagFlowView()
    private let summaryLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 3
        label.lineBreakMode = .byTruncatingTail
        label.cell?.wraps = true
        return label
    }()
    private let summaryToggleButton = Button()
    private let actionRow = NSStackView()
    private let favoriteButton = WelcomeShellClosureButton()
    private let metadataButton = WelcomeShellClosureButton(title: NSLocalizedString("作品资料", comment: ""))
    private let episodesButton = WelcomeShellClosureButton(title: NSLocalizedString("查看剧集", comment: ""))

    private var coverWidthConstraint: Constraint?
    private var coverHeightConstraint: Constraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with item: BangumiDetail) {
        detail = item
        animeId = item.animeId
        isFavorited = item.isFavorited

        titleLabel.text = item.animeTitle
        titleLabel.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.heroTitle)

        let alternateTitles = item.titles
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != item.animeTitle }
        originalTitleLabel.stringValue = Array(alternateTitles.prefix(2)).joined(separator: "  /  ")
        originalTitleLabel.isHidden = originalTitleLabel.stringValue.isEmpty

        if item.rating > 0 {
            ratingBadge.stringValue = String(format: " ★ %.1f ", item.rating)
            ratingBadge.isHidden = false
            ratingBadge.setAccessibilityLabel(String(
                format: NSLocalizedString("评分 %.1f", comment: ""),
                item.rating
            ))
        } else {
            ratingBadge.isHidden = true
        }

        let sourceRatings = item.ratingDetails.items
            .sorted { $0.source.localizedCaseInsensitiveCompare($1.source) == .orderedAscending }
            .filter { !$0.source.isEmpty && $0.rating > 0 }
            .map { String(format: "%@ %.1f", $0.source, $0.rating) }
        ratingSourceLabel.stringValue = sourceRatings.joined(separator: "  ·  ")
        ratingSourceLabel.isHidden = sourceRatings.isEmpty

        var metaParts: [String] = []
        metaParts.append(item.isOnAir
            ? NSLocalizedString("连载中", comment: "")
            : NSLocalizedString("已完结", comment: ""))
        let typeName = item.typeDescription.isEmpty ? item.type.displayName : item.typeDescription
        if !typeName.isEmpty {
            metaParts.append(typeName)
        }
        if !item.episodes.isEmpty {
            metaParts.append(String(
                format: NSLocalizedString("%d 集", comment: ""),
                item.episodes.count
            ))
        }
        if item.isOnAir, (0...6).contains(item.airDay) {
            let weekday = WelcomeShellDataMapper.weekdayTitle(for: item.airDay)
            if !weekday.isEmpty {
                metaParts.append(String(format: NSLocalizedString("%@更新", comment: ""), weekday))
            }
        }
        metaLabel.stringValue = metaParts.joined(separator: "  ·  ")
        metaLabel.textColor = item.isOnAir ? .mainColor : .secondaryLabelColor

        let sortedTags = item.tags
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.count > $1.count }
            .map { $0.name }
        tagFlow.configure(tagNames: sortedTags)
        tagFlow.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.heroTags)
        tagFlow.onMore = { [weak self] sourceView in
            self?.showTagPopover(sourceView: sourceView)
        }

        let summary = item.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let intro = item.intro.trimmingCharacters(in: .whitespacesAndNewlines)
        let synopsis = summary.isEmpty ? intro : summary
        summaryLabel.stringValue = synopsis.isEmpty ? NSLocalizedString("暂无简介", comment: "") : synopsis
        summaryLabel.textColor = synopsis.isEmpty ? .tertiaryLabelColor : .secondaryLabelColor
        isSummaryExpanded = false
        summaryLabel.maximumNumberOfLines = 3
        updateSummaryToggleTitle()

        isFavorited = item.isFavorited
        updateFavoriteButton()

        if let url = URL(string: item.imageUrl), !item.imageUrl.isEmpty {
            coverImageView.image = NSImage.safeSystemSymbol("film")
            coverImageView.kf.setImage(with: url)
        } else {
            coverImageView.image = NSImage.safeSystemSymbol("film")
        }
        coverImageView.contentTintColor = .tertiaryLabelColor
        coverImageView.setAccessibilityLabel(item.animeTitle)

        setAccessibilityLabel([item.animeTitle, metaLabel.stringValue]
            .filter { !$0.isEmpty }
            .joined(separator: "，"))

        needsLayout = true
        layoutSubtreeIfNeeded()
        onLayoutChange?()
    }

    override func layout() {
        super.layout()
        let width = bounds.width
        guard width > 0 else { return }

        if abs(lastLayoutWidth - width) > 0.5 {
            lastLayoutWidth = width
            updateCoverSize(for: width)
        }
        updateCoverShadowPath()
        updateSummaryOverflowIfNeeded()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            self?.ratingBadge.layer?.backgroundColor = NSColor.mainColor.cgColor
            self?.coverImageView.layer?.borderColor = NSColor.separatorColor
                .withAlphaComponent(0.4).cgColor
        }
    }

    // MARK: - Setup

    private func setup() {
        setAccessibilityIdentifier(AccessibilityID.BangumiDetail.hero)
        contentStack.spacing = 0

        coverWrapper.wantsLayer = true
        coverWrapper.layer?.shadowColor = NSColor.black.cgColor
        coverWrapper.layer?.shadowOpacity = 0.18
        coverWrapper.layer?.shadowRadius = 10
        coverWrapper.layer?.shadowOffset = NSSize(width: 0, height: -4)

        coverImageView.setScaling(.aspectFill)
        coverImageView.wantsLayer = true
        coverImageView.layer?.cornerRadius = 10
        coverImageView.layer?.cornerCurve = .continuous
        coverImageView.layer?.masksToBounds = true
        coverImageView.layer?.borderWidth = 1
        coverImageView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor

        ratingBadge.font = .systemFont(ofSize: 12, weight: .bold)
        ratingBadge.textColor = .white
        ratingBadge.alignment = .center
        ratingBadge.wantsLayer = true
        ratingBadge.layer?.backgroundColor = NSColor.mainColor.cgColor
        ratingBadge.layer?.cornerRadius = 6
        ratingBadge.layer?.cornerCurve = .continuous
        ratingBadge.layer?.masksToBounds = true

        coverWrapper.addSubview(coverImageView)
        coverWrapper.addSubview(ratingBadge)
        coverImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        coverWrapper.snp.makeConstraints { make in
            coverWidthConstraint = make.width.equalTo(160).constraint
            coverHeightConstraint = make.height.equalTo(224).constraint
        }
        ratingBadge.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview().inset(7)
            make.height.equalTo(22)
            make.width.greaterThanOrEqualTo(52)
        }

        configureInfoStack()
        topRow.orientation = .horizontal
        topRow.alignment = .top
        topRow.distribution = .fill
        topRow.spacing = 18
        topRow.addArrangedSubview(coverWrapper)
        topRow.addArrangedSubview(infoStack)
        coverWrapper.setContentHuggingPriority(.required, for: .horizontal)
        coverWrapper.setContentCompressionResistancePriority(.required, for: .horizontal)
        infoStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        infoStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentStack.addArrangedSubview(topRow)
        contentStack.addArrangedSubview(actionRow)
        contentStack.setCustomSpacing(14, after: topRow)
        topRow.snp.makeConstraints { make in
            make.width.equalTo(contentStack)
        }

        tagFlow.onHeightChange = { [weak self] in
            self?.onLayoutChange?()
        }
    }

    private func configureInfoStack() {
        infoStack.orientation = .vertical
        infoStack.alignment = .width
        infoStack.spacing = 4
        infoStack.addArrangedSubview(titleLabel)
        infoStack.addArrangedSubview(originalTitleLabel)
        infoStack.addArrangedSubview(ratingSourceLabel)
        infoStack.addArrangedSubview(metaLabel)
        infoStack.addArrangedSubview(tagFlow)
        infoStack.addArrangedSubview(summaryLabel)
        infoStack.addArrangedSubview(summaryToggleButton)

        infoStack.setCustomSpacing(6, after: originalTitleLabel)
        infoStack.setCustomSpacing(8, after: ratingSourceLabel)
        infoStack.setCustomSpacing(8, after: metaLabel)
        infoStack.setCustomSpacing(10, after: tagFlow)
        infoStack.setCustomSpacing(4, after: summaryLabel)

        summaryToggleButton.title = NSLocalizedString("展开", comment: "")
        summaryToggleButton.isBordered = false
        summaryToggleButton.bezelStyle = .inline
        summaryToggleButton.contentTintColor = .mainColor
        summaryToggleButton.font = .systemFont(ofSize: 12, weight: .medium)
        summaryToggleButton.addTarget(self, action: #selector(summaryToggleClicked))
        summaryToggleButton.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.summaryToggle)
        summaryToggleButton.setContentHuggingPriority(.required, for: .horizontal)
        summaryToggleButton.isHidden = true

        favoriteButton.bezelStyle = .rounded
        favoriteButton.imagePosition = .imageLeading
        favoriteButton.contentTintColor = .mainColor
        favoriteButton.font = .systemFont(ofSize: 12, weight: .semibold)
        favoriteButton.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.favorite)
        favoriteButton.onClick = { [weak self] in
            self?.favoriteClicked()
        }

        metadataButton.bezelStyle = .rounded
        metadataButton.image = welcomeShellSymbol("info.circle", pointSize: 12, weight: .medium)
        metadataButton.imagePosition = .imageLeading
        metadataButton.contentTintColor = .mainColor
        metadataButton.font = .systemFont(ofSize: 12, weight: .medium)
        metadataButton.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.heroMetadata)
        metadataButton.onClick = { [weak self] in
            self?.onTapMetadata?()
        }

        episodesButton.bezelStyle = .rounded
        episodesButton.image = welcomeShellSymbol("list.bullet.rectangle", pointSize: 12, weight: .medium)
        episodesButton.imagePosition = .imageLeading
        episodesButton.contentTintColor = .mainColor
        episodesButton.font = .systemFont(ofSize: 12, weight: .medium)
        episodesButton.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.heroEpisodes)
        episodesButton.onClick = { [weak self] in
            self?.onTapEpisodes?()
        }

        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.distribution = .fill
        actionRow.spacing = 8
        [favoriteButton, metadataButton, episodesButton].forEach { button in
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            actionRow.addArrangedSubview(button)
        }
        let trailingSpacer = NSView()
        trailingSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actionRow.addArrangedSubview(trailingSpacer)
    }

    // MARK: - Layout

    private func updateCoverSize(for width: CGFloat) {
        let compact = width < 576
        guard compact != usesCompactCover else { return }
        usesCompactCover = compact
        coverWidthConstraint?.update(offset: compact ? 110 : 160)
        coverHeightConstraint?.update(offset: compact ? 154 : 224)
        titleLabel.font = .systemFont(ofSize: compact ? 24 : 26, weight: .bold)
    }

    private func updateCoverShadowPath() {
        let bounds = coverWrapper.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        coverWrapper.layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: 10,
            cornerHeight: 10,
            transform: nil
        )
    }

    private func updateSummaryOverflowIfNeeded() {
        guard summaryLabel.stringValue != NSLocalizedString("暂无简介", comment: "") else {
            if !summaryToggleButton.isHidden {
                summaryToggleButton.isHidden = true
                DispatchQueue.main.async { [weak self] in
                    self?.onLayoutChange?()
                }
            }
            return
        }

        let width = summaryLabel.bounds.width
        guard width > 0 else { return }
        let font = summaryLabel.font ?? NSFont.systemFont(ofSize: 12.5)
        let height = (summaryLabel.stringValue as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        ).height
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let needsToggle = isSummaryExpanded || height > lineHeight * 3 + 1
        guard summaryToggleButton.isHidden != !needsToggle else { return }
        summaryToggleButton.isHidden = !needsToggle
        DispatchQueue.main.async { [weak self] in
            self?.onLayoutChange?()
        }
    }

    private func updateSummaryToggleTitle() {
        summaryToggleButton.title = isSummaryExpanded
            ? NSLocalizedString("收起", comment: "")
            : NSLocalizedString("展开", comment: "")
    }

    private func showTagPopover(sourceView: NSView) {
        guard let detail = detail else { return }
        tagPopover?.close()

        let controller = BangumiDetailTagPopoverViewController(tags: detail.tags)
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.show(relativeTo: sourceView.bounds, of: sourceView, preferredEdge: .maxY)
        tagPopover = popover
    }

    // MARK: - Actions

    private func favoriteClicked() {
        isFavorited.toggle()
        updateFavoriteButton()
        onFavoriteToggle?(animeId, isFavorited)
    }

    private func updateFavoriteButton() {
        favoriteButton.title = isFavorited
            ? NSLocalizedString("已关注", comment: "")
            : NSLocalizedString("关注", comment: "")
        favoriteButton.image = NSImage(
            systemSymbolName: isFavorited ? "heart.fill" : "heart",
            accessibilityDescription: nil
        )
        favoriteButton.toolTip = favoriteButton.title
        favoriteButton.setAccessibilityLabel(favoriteButton.title)
    }

    @objc private func summaryToggleClicked() {
        isSummaryExpanded.toggle()
        summaryLabel.maximumNumberOfLines = isSummaryExpanded ? 0 : 3
        updateSummaryToggleTitle()
        needsLayout = true
        onLayoutChange?()
    }
}
