//
//  PlayHistoryRowView.swift
//  AniXPlayer
//
//  macOS：播放历史列表行。左侧小海报，右侧标题、上次播放时间与剧集 chip。
//

import Cocoa
import SnapKit
import Kingfisher

// MARK: - 状态文案

extension PlayHistoryEpisodeStatus {
    var localizedTitle: String {
        switch self {
        case .watched:
            return NSLocalizedString("已看", comment: "")
        case .notWatched:
            return NSLocalizedString("未看", comment: "")
        case .notOnAir:
            return NSLocalizedString("未上映", comment: "")
        }
    }
}

// MARK: - Chip

final class PlayHistoryEpisodeChipView: NSView {

    static let font = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let horizontalPadding: CGFloat = 8
    static let minimumWidth: CGFloat = 30
    static let height: CGFloat = 24
    private static let textSafetyPadding: CGFloat = 2

    private var title: String = ""
    private var status: PlayHistoryEpisodeStatus = .notWatched
    var onClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.cornerCurve = .continuous
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !title.isEmpty else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.font,
            .foregroundColor: statusTextColor,
            .paragraphStyle: paragraph
        ]
        let lineHeight = ceil(Self.font.ascender - Self.font.descender + Self.font.leading)
        let textRect = NSRect(
            x: Self.horizontalPadding,
            y: max(0, (bounds.height - lineHeight) / 2),
            width: max(0, bounds.width - Self.horizontalPadding * 2),
            height: lineHeight
        )
        (title as NSString).draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    override func mouseUp(with event: NSEvent) {
        if let onClick = onClick {
            onClick()
        } else {
            super.mouseUp(with: event)
        }
    }

    func configure(title: String, status: PlayHistoryEpisodeStatus, tooltip: String?) {
        self.title = title
        self.status = status
        toolTip = tooltip
        setAccessibilityLabel([title, status.localizedTitle].filter { !$0.isEmpty }.joined(separator: "，"))
        updateColors()
        needsDisplay = true
    }

    static func width(for title: String) -> CGFloat {
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return max(
            minimumWidth,
            ceil(textWidth) + horizontalPadding * 2 + textSafetyPadding
        )
    }

    private var statusTextColor: NSColor {
        switch status {
        case .watched:
            return .mainColor
        case .notWatched:
            return .secondaryLabelColor
        case .notOnAir:
            return .systemPink
        }
    }

    private func updateColors() {
        let background: NSColor
        switch status {
        case .watched:
            background = NSColor.mainColor.withAlphaComponent(0.16)
        case .notWatched:
            background = NSColor.secondaryLabelColor.withAlphaComponent(0.10)
        case .notOnAir:
            background = NSColor.systemPink.withAlphaComponent(0.16)
        }

        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            self?.layer?.backgroundColor = background.cgColor
        }
        needsDisplay = true
    }
}

// MARK: - Flow

final class PlayHistoryEpisodeFlowView: NSView {

    private var chipViews: [PlayHistoryEpisodeChipView] = []
    private var chipWidths: [CGFloat] = []
    var onChipClick: (() -> Void)?

    override var isFlipped: Bool { true }

    static func height(for episodes: [PlayHistoryEpisode], width: CGFloat) -> CGFloat {
        let widths = episodes.map { PlayHistoryEpisodeChipView.width(for: $0.chipTitle) }
        return PlayHistoryRowLayout.flowHeight(chipWidths: widths, availableWidth: width)
    }

    func configure(episodes: [PlayHistoryEpisode], now: Date) {
        chipViews.forEach { $0.removeFromSuperview() }
        chipViews.removeAll()
        chipWidths.removeAll()

        for episode in episodes {
            let chip = PlayHistoryEpisodeChipView()
            let status = episode.status(now: now)
            let fullTitle = episode.episodeTitle.isEmpty ? episode.chipTitle : episode.episodeTitle
            let tooltip = [fullTitle, status.localizedTitle]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            chip.configure(title: episode.chipTitle, status: status, tooltip: tooltip)
            chip.onClick = { [weak self] in self?.onChipClick?() }
            chip.setAccessibilityIdentifier("\(AccessibilityID.History.chipPrefix)\(episode.episodeId)")
            addSubview(chip)
            chipViews.append(chip)
            chipWidths.append(PlayHistoryEpisodeChipView.width(for: episode.chipTitle))
        }

        needsLayout = true
    }

    override func layout() {
        super.layout()

        let availableWidth = max(bounds.width, 1)
        var x: CGFloat = 0
        var y: CGFloat = 0

        for (index, chip) in chipViews.enumerated() {
            guard index < chipWidths.count else { continue }
            let chipWidth = min(chipWidths[index], availableWidth)

            if x > 0, x + chipWidth > availableWidth {
                x = 0
                y += PlayHistoryRowLayout.chipHeight + PlayHistoryRowLayout.chipLineSpacing
            }

            chip.frame = NSRect(
                x: x,
                y: y,
                width: chipWidth,
                height: PlayHistoryRowLayout.chipHeight
            )
            x += chipWidth + PlayHistoryRowLayout.chipSpacing
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // 空白区域不要拦截点击，让整行点击继续冒泡到 NSTableView；
        // chip 自身仍然是可点击、可显示 tooltip 的。
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

// MARK: - Row

private final class PlayHistoryPosterImageView: ImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private final class PlayHistoryPassThroughLabel: Label {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

final class PlayHistoryRowView: NSTableCellView {

    var onActivate: (() -> Void)?

    private lazy var posterView: PlayHistoryPosterImageView = {
        let view = PlayHistoryPosterImageView()
        view.setScaling(.aspectFill)
        view.wantsLayer = true
        view.layer?.cornerRadius = 6
        view.layer?.masksToBounds = true
        return view
    }()

    private lazy var titleLabel: PlayHistoryPassThroughLabel = {
        let label = PlayHistoryPassThroughLabel(labelWithString: "")
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .textColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.isSelectable = false
        label.refusesFirstResponder = true
        return label
    }()

    private lazy var timeLabel: PlayHistoryPassThroughLabel = {
        let label = PlayHistoryPassThroughLabel(labelWithString: "")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.isSelectable = false
        label.refusesFirstResponder = true
        return label
    }()

    private let chipsView = PlayHistoryEpisodeFlowView()
    private var chipsHeightConstraint: Constraint?

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        chipsView.onChipClick = { [weak self] in
            self?.onActivate?()
        }

        addSubview(posterView)
        addSubview(titleLabel)
        addSubview(timeLabel)
        addSubview(chipsView)

        posterView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(PlayHistoryRowLayout.verticalInset)
            make.leading.equalToSuperview().offset(PlayHistoryRowLayout.horizontalInset)
            make.width.equalTo(PlayHistoryRowLayout.posterWidth)
            make.height.equalTo(PlayHistoryRowLayout.posterHeight)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(PlayHistoryRowLayout.verticalInset)
            make.leading.equalTo(posterView.snp.trailing).offset(PlayHistoryRowLayout.posterTextGap)
            make.trailing.equalToSuperview().offset(-PlayHistoryRowLayout.horizontalInset)
        }
        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(PlayHistoryRowLayout.titleTimeGap)
            make.leading.trailing.equalTo(titleLabel)
        }
        chipsView.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(PlayHistoryRowLayout.timeChipsGap)
            make.leading.trailing.equalTo(titleLabel)
            chipsHeightConstraint = make.height.equalTo(0).constraint
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updatePosterBackgroundColor()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.separatorColor.withAlphaComponent(0.35).setFill()
        NSBezierPath(
            rect: NSRect(
                x: PlayHistoryRowLayout.horizontalInset,
                y: 0,
                width: max(0, bounds.width - PlayHistoryRowLayout.horizontalInset * 2),
                height: 1
            )
        ).fill()
    }

    static func height(for item: PlayHistoryItem, width: CGFloat) -> CGFloat {
        let availableWidth = PlayHistoryRowLayout.contentWidth(for: max(width, 320))
        let chipsHeight = PlayHistoryEpisodeFlowView.height(for: item.episodes, width: availableWidth)
        return PlayHistoryRowLayout.rowHeight(chipContentHeight: chipsHeight)
    }

    func update(item: PlayHistoryItem, now: Date, width: CGFloat) {
        setAccessibilityIdentifier("\(AccessibilityID.History.itemPrefix)\(item.animeId)")
        setAccessibilityLabel(item.animeTitle)
        toolTip = item.animeTitle

        posterView.kf.cancelDownloadTask()
        posterView.image = nil
        updatePosterBackgroundColor()
        if !item.imageUrl.isEmpty, let url = URL(string: item.imageUrl) {
            posterView.kf.setImage(with: url)
        }

        titleLabel.text = item.animeTitle

        if let lastWatched = item.lastWatched {
            timeLabel.text = String(
                format: NSLocalizedString("上次观看 %@", comment: ""),
                dateFormatter.string(from: lastWatched)
            )
        } else {
            timeLabel.text = String(
                format: NSLocalizedString("上次观看 %@", comment: ""),
                "—"
            )
        }

        chipsView.configure(episodes: item.episodes, now: now)

        let availableWidth = PlayHistoryRowLayout.contentWidth(for: max(width, 320))
        let chipsHeight = PlayHistoryEpisodeFlowView.height(for: item.episodes, width: availableWidth)
        chipsHeightConstraint?.update(offset: chipsHeight)
        needsLayout = true
    }

    private func updatePosterBackgroundColor() {
        let background = NSColor.quaternaryLabelColor.withAlphaComponent(0.12)
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            self?.posterView.layer?.backgroundColor = background.cgColor
        }
    }
}
