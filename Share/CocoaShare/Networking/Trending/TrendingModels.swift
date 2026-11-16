//
//  TrendingModels.swift
//  AniXPlayer
//
//  macOS：排行榜 DTO。字段对齐 Windows TrendingBangumiResponse。
//

import Foundation

struct TrendingSummary: Decodable {
    let title: String
    let rankingType: String
    let period: String
    let scope: String
    let dateFrom: String
    let dateTo: String
    let compareDateFrom: String
    let compareDateTo: String
    let latestDataDate: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        rankingType = (try? c.decodeIfPresent(String.self, forKey: .rankingType)) ?? ""
        period = (try? c.decodeIfPresent(String.self, forKey: .period)) ?? ""
        scope = (try? c.decodeIfPresent(String.self, forKey: .scope)) ?? ""
        dateFrom = (try? c.decodeIfPresent(String.self, forKey: .dateFrom)) ?? ""
        dateTo = (try? c.decodeIfPresent(String.self, forKey: .dateTo)) ?? ""
        compareDateFrom = (try? c.decodeIfPresent(String.self, forKey: .compareDateFrom)) ?? ""
        compareDateTo = (try? c.decodeIfPresent(String.self, forKey: .compareDateTo)) ?? ""
        latestDataDate = (try? c.decodeIfPresent(String.self, forKey: .latestDataDate)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case title, rankingType, period, scope
        case dateFrom, dateTo, compareDateFrom, compareDateTo, latestDataDate
    }
}

final class TrendingItem: Decodable, AnimeListItem {
    let intro: BangumiIntro
    let rank: Int
    let heat: String
    let activeDays: Int
    let previousHeat: String
    let heatDelta: String
    let heatGrowthRate: String
    var isFavorited: Bool

    var animeId: Int { intro.animeId }
    var animeTitle: String { intro.animeTitle }
    var imageUrl: String { intro.imageUrl }
    var rating: Double { intro.rating }
    var isOnAir: Bool { intro.isOnAir }
    var typeDescription: String { "" }

    init(from decoder: Decoder) throws {
        intro = try BangumiIntro(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rank = (try? c.decodeIfPresent(Int.self, forKey: .rank)) ?? 0
        heat = (try? c.decodeIfPresent(String.self, forKey: .heat)) ?? ""
        activeDays = (try? c.decodeIfPresent(Int.self, forKey: .activeDays)) ?? 0
        previousHeat = (try? c.decodeIfPresent(String.self, forKey: .previousHeat)) ?? ""
        heatDelta = (try? c.decodeIfPresent(String.self, forKey: .heatDelta)) ?? ""
        heatGrowthRate = (try? c.decodeIfPresent(String.self, forKey: .heatGrowthRate)) ?? ""
        isFavorited = intro.isFavorited
    }

    private enum CodingKeys: String, CodingKey {
        case rank, heat, activeDays, previousHeat, heatDelta, heatGrowthRate
    }
}

struct TrendingResponse: Decodable {
    let success: Bool
    let errorCode: Int
    let errorMessage: String
    let summary: TrendingSummary?
    let bangumiList: [TrendingItem]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorCode = (try? c.decodeIfPresent(Int.self, forKey: .errorCode)) ?? 0
        errorMessage = (try? c.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        summary = try? c.decodeIfPresent(TrendingSummary.self, forKey: .summary)
        bangumiList = (try? c.decodeIfPresent([TrendingItem].self, forKey: .bangumiList)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorCode, errorMessage, summary, bangumiList
    }
}

enum TrendingMetricMode {
    case hot
    case rising
    case newAnime
}
