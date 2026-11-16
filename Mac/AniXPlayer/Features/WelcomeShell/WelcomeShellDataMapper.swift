//
//  WelcomeShellDataMapper.swift
//  AniXPlayer
//
//  macOS：欢迎页外壳的纯数据映射（不依赖 AppKit，便于单元测试）。
//

import Foundation

// MARK: - Recent play

/// 轻量的最近播放记录（UserDefaults + JSON，不使用数据库）。
struct WelcomeRecentItem: Codable, Equatable {
    let path: String
    let lastOpened: TimeInterval
    let progress: Double?
    let bookmark: Data?
}

// MARK: - Schedule

/// 新番时间表的筛选条件。
enum WelcomeScheduleFilter: Equatable {
    /// airDay：0 表示周日，1-6 表示周一至周六（与服务端一致）。
    case weekday(Int)
    /// 已关注
    case favorited
    /// 全部
    case all
}

/// 季度下拉中的一个选项。
struct WelcomeSeasonOption: Equatable {
    /// 「连载中的新番」没有 year/month。
    let title: String
    let year: Int?
    let month: Int?

    var isCurrentSeason: Bool {
        return year == nil || month == nil
    }

    static let currentSeason = WelcomeSeasonOption(
        title: NSLocalizedString("连载中的新番", comment: ""),
        year: nil,
        month: nil
    )
}

// MARK: - Queue

/// 概览/未看页共用的卡片模型。
struct WelcomeQueueCardItem: Equatable {
    let animeId: Int
    let animeTitle: String
    let episodeTitle: String
    let imageUrl: String
    let description: String
    let airDateText: String
    let isOnAir: Bool
}

// MARK: - Mapper

enum WelcomeShellDataMapper {

    // MARK: Calendar

    /// 服务端的 airDay：0 为周日，1-6 为周一至周六。
    static func currentAirDay(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: now) // 1 = Sunday
        return (weekday - 1) % 7
    }

    static func weekdayTitle(for airDay: Int) -> String {
        switch airDay {
        case 0: return NSLocalizedString("周日", comment: "")
        case 1: return NSLocalizedString("周一", comment: "")
        case 2: return NSLocalizedString("周二", comment: "")
        case 3: return NSLocalizedString("周三", comment: "")
        case 4: return NSLocalizedString("周四", comment: "")
        case 5: return NSLocalizedString("周五", comment: "")
        case 6: return NSLocalizedString("周六", comment: "")
        default: return ""
        }
    }

    // MARK: Bangumi

    /// 已关注优先，其次按标题排序。
    static func sortedBangumi(_ items: [BangumiIntro]) -> [BangumiIntro] {
        return items.sorted { lhs, rhs in
            if lhs.isFavorited != rhs.isFavorited {
                return lhs.isFavorited && !rhs.isFavorited
            }
            return lhs.animeTitle.localizedStandardCompare(rhs.animeTitle) == .orderedAscending
        }
    }

    /// 今日新番：airDay 等于今天，已关注优先 + 标题排序。
    static func todayBangumi(
        _ items: [BangumiIntro],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [BangumiIntro] {
        let today = currentAirDay(now: now, calendar: calendar)
        let filtered = items.filter { $0.airDay == today }
        return sortedBangumi(filtered)
    }

    /// 按星期/关注/全部筛选，再按标题过滤；空搜索词表示不额外过滤。
    static func filterBangumi(
        _ items: [BangumiIntro],
        filter: WelcomeScheduleFilter,
        searchText: String = ""
    ) -> [BangumiIntro] {
        let filtered: [BangumiIntro]
        switch filter {
        case .weekday(let airDay):
            filtered = items.filter { $0.airDay == airDay }
        case .favorited:
            filtered = items.filter { $0.isFavorited }
        case .all:
            filtered = items
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return sortedBangumi(filtered)
        }
        let matched = filtered.filter { item in
            item.animeTitle.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        return sortedBangumi(matched)
    }

    /// 「连载中的新番」+ 服务端季度列表（按年月去重，保留服务端顺序）。
    static func seasonOptions(seasons: [BangumiSeason]) -> [WelcomeSeasonOption] {
        var options: [WelcomeSeasonOption] = [.currentSeason]
        var seen = Set<String>()

        for season in seasons {
            guard season.year > 0, season.month > 0 else { continue }
            let key = "\(season.year)-\(season.month)"
            guard seen.insert(key).inserted else { continue }

            let title: String
            if !season.seasonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = season.seasonName
            } else {
                title = String(format: NSLocalizedString("%d年%d月", comment: ""), season.year, season.month)
            }
            options.append(WelcomeSeasonOption(title: title, year: season.year, month: season.month))
        }
        return options
    }

    /// 首页返回的新番列表；优先 shinBangumiList，空时回退到本季新番字段。
    static func currentSeasonBangumi(from homepage: Homepage) -> [BangumiIntro] {
        if !homepage.shinBangumiList.isEmpty {
            return homepage.shinBangumiList
        }
        return homepage.shinBangumiOfCurrentSeason
    }

    // MARK: Recent play

    /// 最近播放去重（标准化路径）、按时间倒序并截断。
    static func recentItems(_ items: [WelcomeRecentItem], limit: Int) -> [WelcomeRecentItem] {
        guard limit > 0 else { return [] }

        let sorted = items.sorted { $0.lastOpened > $1.lastOpened }
        var seen = Set<String>()
        var result: [WelcomeRecentItem] = []

        for item in sorted {
            let key = URL(fileURLWithPath: item.path)
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .path
            guard seen.insert(key).inserted else { continue }
            result.append(item)
            if result.count >= limit {
                break
            }
        }
        return result
    }

    // MARK: Queue

    static func queueCards(from items: [BangumiQueueIntroV2]) -> [WelcomeQueueCardItem] {
        return items.map { item in
            WelcomeQueueCardItem(
                animeId: item.animeId,
                animeTitle: item.animeTitle,
                episodeTitle: item.episodeTitle,
                imageUrl: item.imageUrl,
                description: item.description,
                airDateText: shortDateText(item.airDate),
                isOnAir: item.isOnAir
            )
        }
    }

    static func queueCards(from items: [BangumiQueueIntro]) -> [WelcomeQueueCardItem] {
        return items.map { item in
            WelcomeQueueCardItem(
                animeId: item.animeId,
                animeTitle: item.animeTitle,
                episodeTitle: item.episodeTitle,
                imageUrl: item.imageUrl,
                description: item.description,
                airDateText: item.airDate,
                isOnAir: item.isOnAir
            )
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func shortDateText(_ date: Date?) -> String {
        guard let date = date else { return "" }
        return shortDateFormatter.string(from: date)
    }
}
