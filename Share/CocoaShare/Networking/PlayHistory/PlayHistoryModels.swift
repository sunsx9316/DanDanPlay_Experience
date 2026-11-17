//
//  PlayHistoryModels.swift
//  AniXPlayer
//
//  macOS：服务端播放历史。字段对齐 Windows UserPlayHistoryResponse。
//

import Foundation

struct PlayHistoryEpisode: Decodable {
    let episodeId: Int
    let episodeTitle: String
    let episodeNumber: String
    let lastWatched: Date?
    let airDate: Date?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        episodeId = (try? c.decodeIfPresent(Int.self, forKey: .episodeId)) ?? 0
        episodeTitle = (try? c.decodeIfPresent(String.self, forKey: .episodeTitle)) ?? ""
        episodeNumber = (try? c.decodeIfPresent(String.self, forKey: .episodeNumber)) ?? ""
        let rawLastWatched: String? = (try? c.decodeIfPresent(String.self, forKey: .lastWatched)) ?? nil
        lastWatched = BangumiQueueDateParser.parse(rawLastWatched)
        let rawAirDate: String? = (try? c.decodeIfPresent(String.self, forKey: .airDate)) ?? nil
        airDate = BangumiQueueDateParser.parse(rawAirDate)
    }

    private enum CodingKeys: String, CodingKey {
        case episodeId, episodeTitle, episodeNumber, lastWatched, airDate
    }
}

// MARK: - 剧集状态与 chip 标题（纯逻辑）

enum PlayHistoryEpisodeStatus: Equatable {
    /// 有上次播放时间。
    case watched
    /// 无上次播放时间，且已上映或没有上映时间。
    case notWatched
    /// 无上次播放时间，上映时间在未来。
    case notOnAir

    static func resolve(lastWatched: Date?, airDate: Date?, now: Date = Date()) -> PlayHistoryEpisodeStatus {
        if lastWatched != nil {
            return .watched
        }
        if let airDate = airDate, airDate > now {
            return .notOnAir
        }
        return .notWatched
    }
}

extension PlayHistoryEpisode {
    /// 优先使用服务端返回的集数；为空时按 Windows 规则从 episodeId / 标题推导。
    var chipTitle: String {
        Self.chipTitle(
            episodeNumber: episodeNumber,
            episodeId: episodeId,
            episodeTitle: episodeTitle
        )
    }

    func status(now: Date = Date()) -> PlayHistoryEpisodeStatus {
        PlayHistoryEpisodeStatus.resolve(lastWatched: lastWatched, airDate: airDate, now: now)
    }

    static func chipTitle(episodeNumber: String, episodeId: Int, episodeTitle: String) -> String {
        let trimmedNumber = episodeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNumber.isEmpty {
            return trimmedNumber
        }

        // Windows：9000 以内是话数，9000 以上是特殊标题。
        let derivedNumber = abs(episodeId) % 10000
        if derivedNumber < 9000 {
            return "\(derivedNumber)"
        }

        let trimmedTitle = episodeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return "#\(episodeId)"
        }

        // Windows：截取第一个空格之前的部分；没有空格时使用完整标题。
        if let firstSpace = trimmedTitle.firstIndex(of: " "),
           firstSpace != trimmedTitle.startIndex {
            return String(trimmedTitle[..<firstSpace])
        }
        return trimmedTitle
    }
}

// MARK: - 列表行布局（纯逻辑，便于单测）

enum PlayHistoryRowLayout {
    static let horizontalInset: CGFloat = 16
    static let verticalInset: CGFloat = 12
    static let posterWidth: CGFloat = 100
    static let posterHeight: CGFloat = 150
    static let posterTextGap: CGFloat = 14
    static let titleHeight: CGFloat = 20
    static let titleTimeGap: CGFloat = 4
    static let timeHeight: CGFloat = 14
    static let timeChipsGap: CGFloat = 8
    static let chipHeight: CGFloat = 24
    static let chipSpacing: CGFloat = 6
    static let chipLineSpacing: CGFloat = 6
    static let minimumHeight: CGFloat = 174

    /// 右侧文字/chip 区域可用宽度。
    static func contentWidth(for rowWidth: CGFloat) -> CGFloat {
        return max(80, rowWidth - horizontalInset * 2 - posterWidth - posterTextGap)
    }

    /// chip 区域高度；行高不足海报高度时用 174pt 兜底。
    static func rowHeight(chipContentHeight: CGFloat) -> CGFloat {
        let infoHeight = verticalInset + titleHeight + titleTimeGap + timeHeight
            + timeChipsGap + max(0, chipContentHeight) + verticalInset
        return max(minimumHeight, infoHeight)
    }

    /// 按可用宽度模拟 flow 换行，返回 chip 区域总高度。
    static func flowHeight(chipWidths: [CGFloat], availableWidth: CGFloat) -> CGFloat {
        guard !chipWidths.isEmpty else { return 0 }
        let width = max(availableWidth, 1)
        var x: CGFloat = 0
        var rowCount = 1

        for chipWidth in chipWidths {
            let clampedWidth = min(max(chipWidth, 1), width)
            if x > 0, x + clampedWidth > width {
                x = 0
                rowCount += 1
            }
            x += clampedWidth + chipSpacing
        }

        return CGFloat(rowCount) * chipHeight + CGFloat(rowCount - 1) * chipLineSpacing
    }
}

struct PlayHistoryAnime: Decodable {
    let animeId: Int
    let animeTitle: String
    let typeDescription: String
    let imageUrl: String
    let isOnAir: Bool
    let episodes: [PlayHistoryEpisode]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        animeId = (try? c.decodeIfPresent(Int.self, forKey: .animeId)) ?? 0
        animeTitle = (try? c.decodeIfPresent(String.self, forKey: .animeTitle)) ?? ""
        typeDescription = (try? c.decodeIfPresent(String.self, forKey: .typeDescription)) ?? ""
        imageUrl = (try? c.decodeIfPresent(String.self, forKey: .imageUrl)) ?? ""
        isOnAir = (try? c.decodeIfPresent(Bool.self, forKey: .isOnAir)) ?? false
        episodes = (try? c.decodeIfPresent([PlayHistoryEpisode].self, forKey: .episodes)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case animeId, animeTitle, typeDescription, imageUrl, isOnAir, episodes
    }
}

struct PlayHistoryResponse: Decodable {
    let success: Bool
    let errorMessage: String
    let animes: [PlayHistoryAnime]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? c.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        animes = (try? c.decodeIfPresent([PlayHistoryAnime].self, forKey: .animes)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage
        case animes = "playHistoryAnimes"
    }
}

struct AddPlayHistoryRequest: Encodable {
    let episodeIdList: [Int]
    let addToFavorite: Bool
    let rating: Int

    init(episodeId: Int, addToFavorite: Bool = false, rating: Int = 0) {
        self.episodeIdList = [episodeId]
        self.addToFavorite = addToFavorite
        self.rating = rating
    }
}
