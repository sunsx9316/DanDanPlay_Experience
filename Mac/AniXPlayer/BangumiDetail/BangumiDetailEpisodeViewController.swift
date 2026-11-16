//
//  BangumiDetailEpisodeViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

final class BangumiDetailEpisodeViewController: WelcomeShellScrollPageViewController {

    private struct EpisodeGroup {
        let title: String
        let subtitle: String
        let episodes: [(index: Int, episode: BangumiEpisode)]
    }

    private var episodes: [BangumiEpisode] = []
    private var seasons: [BangumiEpisodeSeason] = []
    private var localFilesByEpisode: [Int: [LocalLibraryFile]] = [:]
    private var localPlayback: BangumiDetailLocalPlayback?

    func configure(
        episodes: [BangumiEpisode],
        seasons: [BangumiEpisodeSeason],
        localFilesByEpisode: [Int: [LocalLibraryFile]] = [:],
        localPlayback: BangumiDetailLocalPlayback? = nil
    ) {
        self.episodes = episodes
        self.seasons = seasons
        self.localFilesByEpisode = localFilesByEpisode
        self.localPlayback = localPlayback
        if isViewLoaded {
            buildContent()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.episodeList)
        title = NSLocalizedString("分集信息", comment: "")
        buildContent()
    }

    // MARK: - Layout

    private func buildContent() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let header = WelcomeShellPageHeaderView(
            title: NSLocalizedString("分集信息", comment: ""),
            subtitle: String(format: NSLocalizedString("共 %d 集", comment: ""), episodes.count)
        )
        addFullWidth(header, spacingAfter: 2)

        guard !episodes.isEmpty else {
            let card = BangumiDetailCardView()
            let state = WelcomeShellStateView()
            state.configure(title: NSLocalizedString("暂无剧集信息", comment: ""))
            card.contentStack.addArrangedSubview(state)
            addFullWidth(card)
            layoutContent()
            return
        }

        for group in makeGroups() {
            addFullWidth(makeGroupCard(for: group))
        }
        layoutContent()
    }

    private func makeGroupCard(for group: EpisodeGroup) -> NSView {
        let card = BangumiDetailCardView()
        card.addStaticHeader(title: group.title, symbolName: "tv")

        if !group.subtitle.isEmpty {
            let subtitle = welcomeShellLabel(
                group.subtitle,
                font: .systemFont(ofSize: 11.5),
                color: .secondaryLabelColor
            )
            card.contentStack.addArrangedSubview(subtitle)
        }

        for item in group.episodes {
            let localFiles = localFilesByEpisode[item.episode.episodeId] ?? []
            let row = BangumiDetailEpisodeRowView()
            row.configure(
                episode: item.episode,
                index: item.index,
                detail: detailText(for: item.episode),
                localFileCount: localPlayback == nil ? 0 : localFiles.count,
                onPlayLocal: { [weak self] sourceView in
                    guard let self = self else { return }
                    self.localPlayback?.play(
                        files: localFiles,
                        from: sourceView,
                        hostView: self.view
                    )
                },
                onActivate: nil
            )
            row.setAccessibilityIdentifier(
                "\(AccessibilityID.BangumiDetail.episodeItemPrefix)\(item.episode.episodeId)"
            )
            card.contentStack.addArrangedSubview(row)
        }
        return card
    }

    private func makeGroups() -> [EpisodeGroup] {
        guard !seasons.isEmpty else {
            return [EpisodeGroup(
                title: NSLocalizedString("全部剧集", comment: ""),
                subtitle: "",
                episodes: episodes.enumerated().map { (index: $0.offset, episode: $0.element) }
            )]
        }

        var groups: [EpisodeGroup] = []
        var assignedEpisodeIndexes = Set<Int>()
        var consumedEmptySeason = false

        for (index, season) in seasons.enumerated() {
            let seasonID = season.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let items: [(Int, BangumiEpisode)]
            if seasonID.isEmpty {
                if seasons.count == 1 {
                    items = episodes.enumerated().map { ($0.offset, $0.element) }
                } else if !consumedEmptySeason {
                    consumedEmptySeason = true
                    items = episodes.enumerated()
                        .filter { $0.element.seasonId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .map { ($0.offset, $0.element) }
                } else {
                    items = []
                }
            } else {
                items = episodes.enumerated()
                    .filter { $0.element.seasonId.trimmingCharacters(in: .whitespacesAndNewlines) == seasonID }
                    .map { ($0.offset, $0.element) }
            }
            guard !items.isEmpty else { continue }
            items.forEach { assignedEpisodeIndexes.insert($0.0) }

            let title = season.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? String(format: NSLocalizedString("第 %d 季", comment: ""), index + 1)
                : season.name
            var subtitleParts = [String(
                format: NSLocalizedString("%d 集", comment: ""),
                items.count
            )]
            if let airDate = season.airDate {
                subtitleParts.append(String(
                    format: NSLocalizedString("首播 %@", comment: ""),
                    BangumiDetailDateFormatter.day.string(from: airDate)
                ))
            }
            groups.append(EpisodeGroup(
                title: title,
                subtitle: subtitleParts.joined(separator: " · "),
                episodes: items
            ))
        }

        let remaining = episodes.enumerated()
            .filter { !assignedEpisodeIndexes.contains($0.offset) }
            .map { (index: $0.offset, episode: $0.element) }
        if !remaining.isEmpty {
            groups.append(EpisodeGroup(
                title: NSLocalizedString("其他剧集", comment: ""),
                subtitle: String(format: NSLocalizedString("%d 集", comment: ""), remaining.count),
                episodes: remaining
            ))
        }

        if groups.isEmpty {
            return [EpisodeGroup(
                title: NSLocalizedString("全部剧集", comment: ""),
                subtitle: "",
                episodes: episodes.enumerated().map { (index: $0.offset, episode: $0.element) }
            )]
        }
        return groups
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
}
