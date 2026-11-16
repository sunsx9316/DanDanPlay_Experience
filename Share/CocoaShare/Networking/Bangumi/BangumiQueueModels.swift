//
//  BangumiQueueModels.swift
//  AniXPlayer
//
//  macOS：追番队列（未看剧集 / 已关注未看）。
//  字段对齐 Windows BangumiQueueIntroResponseV2 / BangumiQueueDetailsResponseV2。
//

import Foundation

struct BangumiQueueIntroResponse: Decodable {
    let success: Bool
    let errorMessage: String
    let hasMore: Bool
    let bangumiList: [BangumiQueueIntroV2]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? container.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        hasMore = (try? container.decodeIfPresent(Bool.self, forKey: .hasMore)) ?? false
        bangumiList = (try? container.decodeIfPresent([BangumiQueueIntroV2].self, forKey: .bangumiList)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage, hasMore, bangumiList
    }
}

struct BangumiQueueIntroV2: Decodable {
    let animeId: Int
    let animeTitle: String
    let episodeTitle: String
    let airDate: Date?
    let imageUrl: String
    let description: String
    let isOnAir: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        animeId = (try? container.decodeIfPresent(Int.self, forKey: .animeId)) ?? 0
        animeTitle = (try? container.decodeIfPresent(String.self, forKey: .animeTitle)) ?? ""
        episodeTitle = (try? container.decodeIfPresent(String.self, forKey: .episodeTitle)) ?? ""
        imageUrl = (try? container.decodeIfPresent(String.self, forKey: .imageUrl)) ?? ""
        description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""
        isOnAir = (try? container.decodeIfPresent(Bool.self, forKey: .isOnAir)) ?? false
        let rawAirDate: String? = (try? container.decodeIfPresent(String.self, forKey: .airDate)) ?? nil
        airDate = BangumiQueueDateParser.parse(rawAirDate)
    }

    private enum CodingKeys: String, CodingKey {
        case animeId, animeTitle, episodeTitle, airDate, imageUrl, description, isOnAir
    }
}

struct BangumiQueueDetailsResponse: Decodable {
    let success: Bool
    let errorMessage: String
    let bangumiList: [BangumiQueueDetails]
    let unwatchedBangumiList: [BangumiQueueDetails]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? container.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        bangumiList = (try? container.decodeIfPresent([BangumiQueueDetails].self, forKey: .bangumiList)) ?? []
        unwatchedBangumiList = (try? container.decodeIfPresent([BangumiQueueDetails].self, forKey: .unwatchedBangumiList)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage, bangumiList, unwatchedBangumiList
    }
}

struct BangumiQueueDetails: Decodable {
    let animeId: Int
    let animeTitle: String
    let isOnAir: Bool
    let imageUrl: String
    let searchKeyword: String
    let lastWatched: Date?
    let episodes: [BangumiQueueEpisode]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        animeId = (try? container.decodeIfPresent(Int.self, forKey: .animeId)) ?? 0
        animeTitle = (try? container.decodeIfPresent(String.self, forKey: .animeTitle)) ?? ""
        isOnAir = (try? container.decodeIfPresent(Bool.self, forKey: .isOnAir)) ?? false
        imageUrl = (try? container.decodeIfPresent(String.self, forKey: .imageUrl)) ?? ""
        searchKeyword = (try? container.decodeIfPresent(String.self, forKey: .searchKeyword)) ?? ""
        let rawLastWatched: String? = (try? container.decodeIfPresent(String.self, forKey: .lastWatched)) ?? nil
        lastWatched = BangumiQueueDateParser.parse(rawLastWatched)
        episodes = (try? container.decodeIfPresent([BangumiQueueEpisode].self, forKey: .episodes)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case animeId, animeTitle, isOnAir, imageUrl, searchKeyword, lastWatched, episodes
    }

    init(
        animeId: Int,
        animeTitle: String,
        isOnAir: Bool = false,
        imageUrl: String = "",
        searchKeyword: String = "",
        lastWatched: Date? = nil,
        episodes: [BangumiQueueEpisode] = []
    ) {
        self.animeId = animeId
        self.animeTitle = animeTitle
        self.isOnAir = isOnAir
        self.imageUrl = imageUrl
        self.searchKeyword = searchKeyword
        self.lastWatched = lastWatched
        self.episodes = episodes
    }

    /// 最新一集（服务端通常按顺序返回，这里取上映时间最大的一集兜底）。
    var latestEpisode: BangumiQueueEpisode? {
        episodes.max { lhs, rhs in
            (lhs.airDate ?? .distantPast) < (rhs.airDate ?? .distantPast)
        } ?? episodes.last
    }
}

struct BangumiQueueEpisode: Decodable {
    let episodeId: Int
    let episodeTitle: String
    let airDate: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episodeId = (try? container.decodeIfPresent(Int.self, forKey: .episodeId)) ?? 0
        episodeTitle = (try? container.decodeIfPresent(String.self, forKey: .episodeTitle)) ?? ""
        let rawAirDate: String? = (try? container.decodeIfPresent(String.self, forKey: .airDate)) ?? nil
        airDate = BangumiQueueDateParser.parse(rawAirDate)
    }

    private enum CodingKeys: String, CodingKey {
        case episodeId, episodeTitle, airDate
    }

    init(episodeId: Int, episodeTitle: String, airDate: Date? = nil) {
        self.episodeId = episodeId
        self.episodeTitle = episodeTitle
        self.airDate = airDate
    }
}

enum BangumiQueueDateParser {
    private static let internetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let internetDateTimeWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let spaceDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parse(_ string: String?) -> Date? {
        guard let string = string, !string.isEmpty else { return nil }
        if let date = internetDateTime.date(from: string) {
            return date
        }
        if let date = internetDateTimeWithFractionalSeconds.date(from: string) {
            return date
        }
        if let date = dateTime.date(from: string) {
            return date
        }
        if let date = spaceDateTime.date(from: string) {
            return date
        }
        return dateOnly.date(from: string)
    }
}

// MARK: - 分组与排序（纯逻辑）

enum BangumiQueueSectionKind: Int, CaseIterable {
    /// 有未看剧集的追番（服务端 bangumiList）
    case unwatched = 0
    /// 已关注但从未看过（服务端 unwatchedBangumiList）
    case followed = 1
}

struct BangumiQueueSectionModel {
    let kind: BangumiQueueSectionKind
    let items: [BangumiQueueDetails]
}

enum BangumiQueueGrouping {

    /// 合并两份列表并按 animeId 去重；同一作品出现在两边时以「有未看剧集」为准。
    /// 返回顺序与服务端语义一致：先有未看剧集的追番，再已关注未看。
    static func mergedItems(
        watched: [BangumiQueueDetails],
        unwatched: [BangumiQueueDetails]
    ) -> [BangumiQueueDetails] {
        let normalized = normalizedLists(watched: watched, unwatched: unwatched)
        return normalized.watched + normalized.unwatched
    }

    /// 只返回非空分区，顺序为「未看剧集」->「已关注未看」。
    static func sections(
        watched: [BangumiQueueDetails],
        unwatched: [BangumiQueueDetails]
    ) -> [BangumiQueueSectionModel] {
        let normalized = normalizedLists(watched: watched, unwatched: unwatched)
        var result: [BangumiQueueSectionModel] = []
        if !normalized.watched.isEmpty {
            result.append(BangumiQueueSectionModel(kind: .unwatched, items: normalized.watched))
        }
        if !normalized.unwatched.isEmpty {
            result.append(BangumiQueueSectionModel(kind: .followed, items: normalized.unwatched))
        }
        return result
    }

    static func sortedWatched(_ items: [BangumiQueueDetails]) -> [BangumiQueueDetails] {
        items.sorted { lhs, rhs in
            let lhsDate = lhs.lastWatched ?? .distantPast
            let rhsDate = rhs.lastWatched ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            let lhsAirDate = lhs.latestEpisode?.airDate ?? .distantPast
            let rhsAirDate = rhs.latestEpisode?.airDate ?? .distantPast
            if lhsAirDate != rhsAirDate {
                return lhsAirDate > rhsAirDate
            }
            return lhs.animeTitle.localizedStandardCompare(rhs.animeTitle) == .orderedAscending
        }
    }

    static func sortedUnwatched(_ items: [BangumiQueueDetails]) -> [BangumiQueueDetails] {
        items.sorted { lhs, rhs in
            if lhs.isOnAir != rhs.isOnAir {
                return lhs.isOnAir && !rhs.isOnAir
            }
            return lhs.animeTitle.localizedStandardCompare(rhs.animeTitle) == .orderedAscending
        }
    }

    private static func normalizedLists(
        watched: [BangumiQueueDetails],
        unwatched: [BangumiQueueDetails]
    ) -> (watched: [BangumiQueueDetails], unwatched: [BangumiQueueDetails]) {
        var seenAnimeIds = Set<Int>()

        let watchedItems = sortedWatched(watched).filter { item in
            guard item.animeId > 0 else { return false }
            return seenAnimeIds.insert(item.animeId).inserted
        }
        let unwatchedItems = sortedUnwatched(unwatched).filter { item in
            guard item.animeId > 0 else { return false }
            return seenAnimeIds.insert(item.animeId).inserted
        }
        return (watchedItems, unwatchedItems)
    }
}
