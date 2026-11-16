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
    var onPlayLocalEpisode: ((BangumiEpisode, [LocalLibraryFile], NSView) -> Void)?
    var onLayoutChange: (() -> Void)?

    private let previewHintLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        return label
    }()

    private let rowsStack: BangumiDetailFullWidthStackView = {
        let stack = BangumiDetailFullWidthStackView()
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

    func configure(
        with item: BangumiDetail,
        localFilesByEpisode: [Int: [LocalLibraryFile]] = [:]
    ) {
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
            let localFiles = localFilesByEpisode[episode.episodeId] ?? []
            let row = BangumiDetailEpisodeRowView()
            row.configure(
                episode: episode,
                index: index,
                detail: detailText(for: episode),
                localFileCount: onPlayLocalEpisode == nil ? 0 : localFiles.count,
                onPlayLocal: { [weak self] sourceView in
                    self?.onPlayLocalEpisode?(episode, localFiles, sourceView)
                },
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

    private let localPlayButton = WelcomeShellClosureButton(title: NSLocalizedString("本地", comment: ""))

    private var localPlayWidthConstraint: Constraint?
    private var onPlayLocal: ((NSView) -> Void)?
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
        localFileCount: Int = 0,
        onPlayLocal: ((NSView) -> Void)? = nil,
        onActivate: (() -> Void)? = nil
    ) {
        let number = episode.episodeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayNumber = number.isEmpty ? "\(index + 1)" : number
        numberBadge.text = String(format: NSLocalizedString("第%@集", comment: ""), displayNumber)
        titleLabel.text = episode.episodeTitle
        titleLabel.isHidden = episode.episodeTitle.isEmpty
        detailLabel.text = detail
        detailLabel.isHidden = detail.isEmpty

        self.onPlayLocal = onPlayLocal
        updateLocalPlayButton(
            count: localFileCount,
            episodeId: episode.episodeId,
            displayNumber: displayNumber
        )

        self.onActivate = onActivate
        // 没有整行跳转时仍要让「本地」按钮可点击：WelcomeShellTapView 在
        // isTapEnabled == false 时会把整个子视图树的 hitTest 交给上层。
        isTapEnabled = onActivate != nil || (localFileCount > 0 && onPlayLocal != nil)
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
        addSubview(localPlayButton)

        localPlayButton.bezelStyle = .rounded
        localPlayButton.controlSize = .small
        localPlayButton.font = .systemFont(ofSize: 11, weight: .medium)
        localPlayButton.image = welcomeShellSymbol("play.fill", pointSize: 9, weight: .semibold)
        localPlayButton.imagePosition = .imageLeading
        localPlayButton.contentTintColor = .mainColor
        localPlayButton.setContentHuggingPriority(.required, for: .horizontal)
        localPlayButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        localPlayButton.isHidden = true
        localPlayButton.onClick = { [weak self] in
            guard let self = self else { return }
            self.onPlayLocal?(self.localPlayButton)
        }

        numberBadge.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(4)
            make.width.equalTo(64)
            make.height.equalTo(20)
        }
        localPlayButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-6)
            make.centerY.equalToSuperview()
            make.height.equalTo(20)
            localPlayWidthConstraint = make.width.equalTo(0).constraint
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(numberBadge.snp.trailing).offset(10)
            make.top.equalToSuperview().offset(3)
            make.trailing.equalTo(localPlayButton.snp.leading).offset(-8)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(localPlayButton.snp.leading).offset(-8)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.bottom.equalToSuperview().offset(-5)
        }
        updateBadgeColor()
    }

    private func updateLocalPlayButton(count: Int, episodeId: Int, displayNumber: String) {
        guard count > 0 else {
            localPlayButton.isHidden = true
            localPlayWidthConstraint?.update(offset: 0)
            localPlayButton.setAccessibilityIdentifier(nil)
            needsLayout = true
            return
        }

        localPlayButton.isHidden = false
        localPlayWidthConstraint?.update(offset: 72)
        localPlayButton.toolTip = count > 1
            ? String(format: NSLocalizedString("播放本地文件（%d 个）", comment: ""), count)
            : NSLocalizedString("播放本地文件", comment: "")
        localPlayButton.setAccessibilityLabel(String(
            format: NSLocalizedString("播放本地文件：第%@集", comment: ""),
            displayNumber
        ))
        localPlayButton.setAccessibilityIdentifier(
            "\(AccessibilityID.BangumiDetail.episodeLocalPlayPrefix)\(episodeId)"
        )
        needsLayout = true
    }

    private func updateBadgeColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            self?.numberBadge.layer?.backgroundColor = NSColor.mainColor
                .withAlphaComponent(0.12).cgColor
        }
    }
}
