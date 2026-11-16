//
//  BangumiDetailEpisodesCardView.swift
//  AniXPlayer
//
//  macOS：详情页的剧集预览卡片。
//

import Cocoa
import SnapKit

final class BangumiDetailEpisodesCardView: BangumiDetailCardView {

    var onViewAll: (() -> Void)?
    var onActivateEpisode: (() -> Void)?
    var onLayoutChange: (() -> Void)?

    private let previewHintLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        return label
    }()

    private let rowsStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 2
        return stack
    }()

    private let stateView = WelcomeShellStateView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with item: BangumiDetail) {
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !item.episodes.isEmpty else {
            previewHintLabel.isHidden = true
            rowsStack.isHidden = true
            stateView.isHidden = false
            stateView.configure(title: NSLocalizedString("暂无剧集信息", comment: ""))
            onLayoutChange?()
            return
        }

        let lastWatchedIndex = item.episodes.lastIndex { $0.lastWatched != nil }
        let startIndex: Int
        if let lastWatchedIndex = lastWatchedIndex, lastWatchedIndex + 1 < item.episodes.count {
            startIndex = lastWatchedIndex + 1
            let nextEpisode = item.episodes[startIndex]
            previewHintLabel.text = String(
                format: NSLocalizedString("继续观看 · 从第 %@ 集开始", comment: ""),
                episodeNumberText(for: nextEpisode, index: startIndex)
            )
        } else if lastWatchedIndex != nil {
            startIndex = 0
            previewHintLabel.text = NSLocalizedString("已全部观看", comment: "")
        } else {
            startIndex = 0
            previewHintLabel.text = String(
                format: NSLocalizedString("共 %d 集", comment: ""),
                item.episodes.count
            )
        }

        let previewCount = 4
        let endIndex = min(startIndex + previewCount, item.episodes.count)
        var index = startIndex
        while index < endIndex {
            let episode = item.episodes[index]
            let row = BangumiDetailEpisodeRowView()
            row.configure(
                episode: episode,
                index: index,
                detail: detailText(for: episode),
                onActivate: { [weak self] in
                    self?.onActivateEpisode?()
                }
            )
            row.setAccessibilityIdentifier(
                "\(AccessibilityID.BangumiDetail.episodeItemPrefix)\(episode.episodeId)"
            )
            rowsStack.addArrangedSubview(row)
            index += 1
        }

        previewHintLabel.isHidden = false
        rowsStack.isHidden = false
        stateView.isHidden = true
        stateView.reset()
        onLayoutChange?()
    }

    // MARK: - Private

    private func setup() {
        setAccessibilityIdentifier(AccessibilityID.BangumiDetail.episodes)
        let header = addHeader(
            title: NSLocalizedString("剧集", comment: ""),
            symbolName: "list.bullet.rectangle",
            identifier: AccessibilityID.BangumiDetail.episodesHeader,
            onTap: { [weak self] in
                self?.onViewAll?()
            }
        )
        header.trailingStack.addArrangedSubview(makeViewAllButton(
            identifier: AccessibilityID.BangumiDetail.episodesViewAll,
            onTap: { [weak self] in
                self?.onViewAll?()
            }
        ))

        contentStack.addArrangedSubview(previewHintLabel)
        contentStack.addArrangedSubview(rowsStack)
        contentStack.addArrangedSubview(stateView)
        contentStack.setCustomSpacing(2, after: previewHintLabel)

        stateView.setAccessibilityIdentifier("\(AccessibilityID.BangumiDetail.episodes).state")
        stateView.isHidden = true
    }

    private func detailText(for episode: BangumiEpisode) -> String {
        var parts: [String] = []
        if let airDate = episode.airDate {
            parts.append(String(
                format: NSLocalizedString("播出 %@", comment: ""),
                BangumiDetailDateFormatter.day.string(from: airDate)
            ))
        }
        if let lastWatched = episode.lastWatched {
            parts.append(String(
                format: NSLocalizedString("上次观看 %@", comment: ""),
                BangumiDetailDateFormatter.minute.string(from: lastWatched)
            ))
        }
        return parts.joined(separator: "  ·  ")
    }

    private func episodeNumberText(for episode: BangumiEpisode, index: Int) -> String {
        let number = episode.episodeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return number.isEmpty ? "\(index + 1)" : number
    }
}

// MARK: - Row

final class BangumiDetailEpisodeRowView: WelcomeShellTapView {

    private let numberBadge: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .mainColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.wantsLayer = true
        label.layer?.cornerRadius = 5
        label.layer?.cornerCurve = .continuous
        label.layer?.masksToBounds = true
        return label
    }()

    private let titleLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .labelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let detailLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private var onActivate: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBadgeColor()
    }

    func configure(
        episode: BangumiEpisode,
        index: Int,
        detail: String,
        onActivate: (() -> Void)?
    ) {
        let number = episode.episodeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayNumber = number.isEmpty ? "\(index + 1)" : number
        numberBadge.text = String(format: NSLocalizedString("第%@集", comment: ""), displayNumber)
        titleLabel.text = episode.episodeTitle
        titleLabel.isHidden = episode.episodeTitle.isEmpty
        detailLabel.text = detail
        detailLabel.isHidden = detail.isEmpty

        self.onActivate = onActivate
        isTapEnabled = onActivate != nil
        onClick = onActivate
        if onActivate != nil {
            setAccessibilityRole(.button)
        } else {
            setAccessibilityRole(.staticText)
        }
        setAccessibilityLabel([numberBadge.text ?? "", episode.episodeTitle, detail]
            .filter { !$0.isEmpty }
            .joined(separator: "，"))
    }

    private func setup() {
        normalBackground = .clear
        layer?.cornerRadius = 6
        setContentHuggingPriority(.required, for: .vertical)

        addSubview(numberBadge)
        addSubview(titleLabel)
        addSubview(detailLabel)

        numberBadge.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(4)
            make.width.equalTo(64)
            make.height.equalTo(20)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(numberBadge.snp.trailing).offset(10)
            make.top.equalToSuperview().offset(3)
            make.trailing.equalToSuperview().offset(-6)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.bottom.equalToSuperview().offset(-5)
        }
        updateBadgeColor()
    }

    private func updateBadgeColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            self?.numberBadge.layer?.backgroundColor = NSColor.mainColor
                .withAlphaComponent(0.12).cgColor
        }
    }
}
