//
//  SearchUpgradeModels.swift
//  AniXPlayer
//
//  macOS：搜索升级（动画 / 剧集 / 标签 / 高级搜索）。
//  字段对齐 Windows Dandanplay.Entity.Model/Search*.cs。
//

import Foundation

// MARK: - 基础模型

struct SearchUpgradeConfigKey: Decodable, Equatable {
    let key: Int
    let value: String

    init(key: Int, value: String) {
        self.key = key
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intKey = try? c.decodeIfPresent(Int.self, forKey: .key) {
            key = intKey
        } else if let stringKey = try? c.decodeIfPresent(String.self, forKey: .key) {
            key = Int(stringKey) ?? 0
        } else {
            key = 0
        }
        value = (try? c.decodeIfPresent(String.self, forKey: .value)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case key, value
    }
}

struct SearchUpgradeAnimeItem: Decodable, Equatable {
    let animeId: Int
    let bangumiId: String
    let animeTitle: String
    let type: String
    let typeDescription: String
    let imageUrl: String
    let startDate: Date?
    let episodeCount: Int
    let rating: Double
    let isFavorited: Bool

    init(
        animeId: Int,
        bangumiId: String = "",
        animeTitle: String,
        type: String = "",
        typeDescription: String = "",
        imageUrl: String = "",
        startDate: Date? = nil,
        episodeCount: Int = 0,
        rating: Double = 0,
        isFavorited: Bool = false
    ) {
        self.animeId = animeId
        self.bangumiId = bangumiId
        self.animeTitle = animeTitle
        self.type = type
        self.typeDescription = typeDescription
        self.imageUrl = imageUrl
        self.startDate = startDate
        self.episodeCount = episodeCount
        self.rating = rating
        self.isFavorited = isFavorited
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        animeId = (try? c.decodeIfPresent(Int.self, forKey: .animeId)) ?? 0
        bangumiId = (try? c.decodeIfPresent(String.self, forKey: .bangumiId)) ?? ""
        animeTitle = (try? c.decodeIfPresent(String.self, forKey: .animeTitle)) ?? ""
        type = (try? c.decodeIfPresent(String.self, forKey: .type)) ?? ""
        typeDescription = (try? c.decodeIfPresent(String.self, forKey: .typeDescription)) ?? ""
        imageUrl = (try? c.decodeIfPresent(String.self, forKey: .imageUrl)) ?? ""
        episodeCount = (try? c.decodeIfPresent(Int.self, forKey: .episodeCount)) ?? 0
        rating = (try? c.decodeIfPresent(Double.self, forKey: .rating)) ?? 0
        isFavorited = (try? c.decodeIfPresent(Bool.self, forKey: .isFavorited)) ?? false
        if let rawDate = try? c.decodeIfPresent(String.self, forKey: .startDate) {
            startDate = DDPDateParser.parse(rawDate)
        } else {
            startDate = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case animeId, bangumiId, animeTitle, type, typeDescription, imageUrl
        case startDate, episodeCount, rating, isFavorited
    }
}

struct SearchUpgradeEpisodeItem: Decodable, Equatable {
    let episodeId: Int
    let episodeTitle: String

    init(episodeId: Int, episodeTitle: String) {
        self.episodeId = episodeId
        self.episodeTitle = episodeTitle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        episodeId = (try? c.decodeIfPresent(Int.self, forKey: .episodeId)) ?? 0
        episodeTitle = (try? c.decodeIfPresent(String.self, forKey: .episodeTitle)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case episodeId, episodeTitle
    }
}

struct SearchUpgradeEpisodeAnime: Decodable, Equatable {
    let animeId: Int
    let animeTitle: String
    let type: String
    let typeDescription: String
    let imageUrl: String
    let episodes: [SearchUpgradeEpisodeItem]

    init(
        animeId: Int,
        animeTitle: String,
        type: String = "",
        typeDescription: String = "",
        imageUrl: String = "",
        episodes: [SearchUpgradeEpisodeItem] = []
    ) {
        self.animeId = animeId
        self.animeTitle = animeTitle
        self.type = type
        self.typeDescription = typeDescription
        self.imageUrl = imageUrl
        self.episodes = episodes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        animeId = (try? c.decodeIfPresent(Int.self, forKey: .animeId)) ?? 0
        animeTitle = (try? c.decodeIfPresent(String.self, forKey: .animeTitle)) ?? ""
        type = (try? c.decodeIfPresent(String.self, forKey: .type)) ?? ""
        typeDescription = (try? c.decodeIfPresent(String.self, forKey: .typeDescription)) ?? ""
        imageUrl = (try? c.decodeIfPresent(String.self, forKey: .imageUrl)) ?? ""
        episodes = (try? c.decodeIfPresent([SearchUpgradeEpisodeItem].self, forKey: .episodes)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case animeId, animeTitle, type, typeDescription, imageUrl, episodes
    }
}

struct SearchUpgradeBangumiItem: Decodable, Equatable {
    let animeId: Int
    let bangumiId: String
    let animeTitle: String
    let type: String
    let typeDescription: String
    let imageUrl: String
    let startDate: Date?
    let episodeCount: Int
    let rating: Double
    let isFavorited: Bool
    let rank: Int
    let searchKeyword: String
    let isOnAir: Bool
    let isRestricted: Bool
    let intro: String

    init(
        animeId: Int,
        bangumiId: String = "",
        animeTitle: String,
        type: String = "",
        typeDescription: String = "",
        imageUrl: String = "",
        startDate: Date? = nil,
        episodeCount: Int = 0,
        rating: Double = 0,
        isFavorited: Bool = false,
        rank: Int = 0,
        searchKeyword: String = "",
        isOnAir: Bool = false,
        isRestricted: Bool = false,
        intro: String = ""
    ) {
        self.animeId = animeId
        self.bangumiId = bangumiId
        self.animeTitle = animeTitle
        self.type = type
        self.typeDescription = typeDescription
        self.imageUrl = imageUrl
        self.startDate = startDate
        self.episodeCount = episodeCount
        self.rating = rating
        self.isFavorited = isFavorited
        self.rank = rank
        self.searchKeyword = searchKeyword
        self.isOnAir = isOnAir
        self.isRestricted = isRestricted
        self.intro = intro
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        animeId = (try? c.decodeIfPresent(Int.self, forKey: .animeId)) ?? 0
        bangumiId = (try? c.decodeIfPresent(String.self, forKey: .bangumiId)) ?? ""
        animeTitle = (try? c.decodeIfPresent(String.self, forKey: .animeTitle)) ?? ""
        type = (try? c.decodeIfPresent(String.self, forKey: .type)) ?? ""
        typeDescription = (try? c.decodeIfPresent(String.self, forKey: .typeDescription)) ?? ""
        imageUrl = (try? c.decodeIfPresent(String.self, forKey: .imageUrl)) ?? ""
        episodeCount = (try? c.decodeIfPresent(Int.self, forKey: .episodeCount)) ?? 0
        rating = (try? c.decodeIfPresent(Double.self, forKey: .rating)) ?? 0
        isFavorited = (try? c.decodeIfPresent(Bool.self, forKey: .isFavorited)) ?? false
        rank = (try? c.decodeIfPresent(Int.self, forKey: .rank)) ?? 0
        searchKeyword = (try? c.decodeIfPresent(String.self, forKey: .searchKeyword)) ?? ""
        isOnAir = (try? c.decodeIfPresent(Bool.self, forKey: .isOnAir)) ?? false
        isRestricted = (try? c.decodeIfPresent(Bool.self, forKey: .isRestricted)) ?? false
        intro = (try? c.decodeIfPresent(String.self, forKey: .intro)) ?? ""
        if let rawDate = try? c.decodeIfPresent(String.self, forKey: .startDate) {
            startDate = DDPDateParser.parse(rawDate)
        } else {
            startDate = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case animeId, bangumiId, animeTitle, type, typeDescription, imageUrl
        case startDate, episodeCount, rating, isFavorited
        case rank, searchKeyword, isOnAir, isRestricted, intro
    }
}

// MARK: - 响应

protocol SearchUpgradeServerResponse {
    var success: Bool { get }
    var errorMessage: String { get }
}

struct SearchUpgradeAnimeResponse: Decodable, SearchUpgradeServerResponse {
    let success: Bool
    let errorMessage: String
    let animes: [SearchUpgradeAnimeItem]

    init(success: Bool = true, errorMessage: String = "", animes: [SearchUpgradeAnimeItem] = []) {
        self.success = success
        self.errorMessage = errorMessage
        self.animes = animes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? c.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        animes = (try? c.decodeIfPresent([SearchUpgradeAnimeItem].self, forKey: .animes)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage, animes
    }
}

struct SearchUpgradeEpisodesResponse: Decodable, SearchUpgradeServerResponse {
    let success: Bool
    let errorMessage: String
    let hasMore: Bool
    let animes: [SearchUpgradeEpisodeAnime]

    init(
        success: Bool = true,
        errorMessage: String = "",
        hasMore: Bool = false,
        animes: [SearchUpgradeEpisodeAnime] = []
    ) {
        self.success = success
        self.errorMessage = errorMessage
        self.hasMore = hasMore
        self.animes = animes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? c.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        hasMore = (try? c.decodeIfPresent(Bool.self, forKey: .hasMore)) ?? false
        animes = (try? c.decodeIfPresent([SearchUpgradeEpisodeAnime].self, forKey: .animes)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage, hasMore, animes
    }
}

struct SearchUpgradeBangumiResponse: Decodable, SearchUpgradeServerResponse {
    let success: Bool
    let errorMessage: String
    let bangumis: [SearchUpgradeBangumiItem]

    init(success: Bool = true, errorMessage: String = "", bangumis: [SearchUpgradeBangumiItem] = []) {
        self.success = success
        self.errorMessage = errorMessage
        self.bangumis = bangumis
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? c.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        bangumis = (try? c.decodeIfPresent([SearchUpgradeBangumiItem].self, forKey: .bangumis)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage, bangumis
    }
}

struct SearchUpgradeAdvancedConfigResponse: Decodable, SearchUpgradeServerResponse {
    let success: Bool
    let errorMessage: String
    let types: [SearchUpgradeConfigKey]
    let tags: [SearchUpgradeConfigKey]
    let sorts: [SearchUpgradeConfigKey]
    let minYear: Int
    let maxYear: Int

    init(
        success: Bool = true,
        errorMessage: String = "",
        types: [SearchUpgradeConfigKey] = [],
        tags: [SearchUpgradeConfigKey] = [],
        sorts: [SearchUpgradeConfigKey] = [],
        minYear: Int = 1970,
        maxYear: Int = Calendar(identifier: .gregorian).component(.year, from: Date())
    ) {
        self.success = success
        self.errorMessage = errorMessage
        self.types = types
        self.tags = tags
        self.sorts = sorts
        self.minYear = minYear
        self.maxYear = maxYear
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? c.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        types = (try? c.decodeIfPresent([SearchUpgradeConfigKey].self, forKey: .types)) ?? []
        tags = (try? c.decodeIfPresent([SearchUpgradeConfigKey].self, forKey: .tags)) ?? []
        sorts = (try? c.decodeIfPresent([SearchUpgradeConfigKey].self, forKey: .sorts)) ?? []
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        minYear = (try? c.decodeIfPresent(Int.self, forKey: .minYear)) ?? 1970
        maxYear = (try? c.decodeIfPresent(Int.self, forKey: .maxYear)) ?? currentYear
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage, types, tags, sorts, minYear, maxYear
    }

    /// 配置接口失败时的内置默认值；保证高级搜索仍然可用。
    static func fallback(referenceDate: Date = Date()) -> SearchUpgradeAdvancedConfigResponse {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: referenceDate)
        return SearchUpgradeAdvancedConfigResponse(
            types: [],
            tags: [],
            sorts: SearchUpgradeSort.allCases.map {
                SearchUpgradeConfigKey(key: $0.rawValue, value: $0.title)
            },
            minYear: min(1970, currentYear),
            maxYear: currentYear
        )
    }
}

// MARK: - 排序

/// 与 Windows `SearchSort` 完全一致。
enum SearchUpgradeSort: Int, CaseIterable {
    case defaultSort = 0
    case nameAsc = 1
    case nameDesc = 2
    case startDateAsc = 3
    case startDateDesc = 4
    case rateAsc = 5
    case rateDesc = 6

    var title: String {
        switch self {
        case .defaultSort:
            return NSLocalizedString("默认排序", comment: "")
        case .nameAsc:
            return NSLocalizedString("名称", comment: "")
        case .nameDesc:
            return NSLocalizedString("名称（倒序）", comment: "")
        case .startDateAsc:
            return NSLocalizedString("上映时间（由旧到新）", comment: "")
        case .startDateDesc:
            return NSLocalizedString("上映时间（由新到旧）", comment: "")
        case .rateAsc:
            return NSLocalizedString("评分（由低到高）", comment: "")
        case .rateDesc:
            return NSLocalizedString("评分（由高到低）", comment: "")
        }
    }
}

// MARK: - 错误

enum SearchUpgradeError: LocalizedError, Equatable {
    case emptyKeyword
    case emptyTags
    case tooManyTags(max: Int)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .emptyKeyword:
            return NSLocalizedString("请输入搜索关键词", comment: "")
        case .emptyTags:
            return NSLocalizedString("请输入至少一个标签", comment: "")
        case .tooManyTags(let max):
            return String(format: NSLocalizedString("最多只能使用 %d 个标签", comment: ""), max)
        case .server(let message):
            return message.isEmpty ? NSLocalizedString("搜索失败，请稍后重试", comment: "") : message
        }
    }
}

// MARK: - 请求 URL / 参数

struct SearchUpgradeAdvancedQuery {
    let source: String
    let keyword: String?
    let type: Int?
    let tags: [String]
    let year: Int?
    let month: Int?
    let minRate: Int?
    let maxRate: Int?
    let restricted: Bool?
    let sort: SearchUpgradeSort?

    init(
        source: String = SearchUpgradeRequest.defaultSource,
        keyword: String? = nil,
        type: Int? = nil,
        tags: [String] = [],
        year: Int? = nil,
        month: Int? = nil,
        minRate: Int? = nil,
        maxRate: Int? = nil,
        restricted: Bool? = nil,
        sort: SearchUpgradeSort? = nil
    ) throws {
        self.source = source
        let trimmedKeyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.keyword = trimmedKeyword.isEmpty ? nil : trimmedKeyword
        self.type = type
        self.tags = tags.isEmpty ? [] : try SearchUpgradeRequest.normalizedTags(tags)
        self.year = year
        self.month = month
        self.minRate = minRate
        self.maxRate = maxRate
        self.restricted = restricted
        self.sort = sort
    }

    var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: "source", value: source)]
        if let keyword = keyword {
            items.append(URLQueryItem(name: "keyword", value: keyword))
        }
        if let type = type {
            items.append(URLQueryItem(name: "type", value: String(type)))
        }
        if !tags.isEmpty {
            items.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
        }
        if let year = year {
            items.append(URLQueryItem(name: "year", value: String(year)))
        }
        if let month = month {
            items.append(URLQueryItem(name: "month", value: String(month)))
        }
        if let minRate = minRate {
            items.append(URLQueryItem(name: "minRate", value: String(minRate)))
        }
        if let maxRate = maxRate {
            items.append(URLQueryItem(name: "maxRate", value: String(maxRate)))
        }
        if let restricted = restricted {
            items.append(URLQueryItem(name: "restricted", value: restricted ? "true" : "false"))
        }
        if let sort = sort {
            items.append(URLQueryItem(name: "sort", value: String(sort.rawValue)))
        }
        return items
    }
}

enum SearchUpgradeRequest {
    /// Windows 高级搜索默认使用弹弹play 数据库（source = ""）。
    static let defaultSource = ""
    static let maxTagCount = 10

    static func animeURL(keyword: String, environment: APIEnvironment = .current()) throws -> URL {
        let keyword = try requiredKeyword(keyword)
        return try makeURL(path: "/search/anime", queryItems: [
            URLQueryItem(name: "keyword", value: keyword),
        ], environment: environment)
    }

    static func episodesURL(
        anime: String,
        episode: String? = nil,
        environment: APIEnvironment = .current()
    ) throws -> URL {
        let anime = try requiredKeyword(anime)
        var items = [URLQueryItem(name: "anime", value: anime)]
        let episode = episode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !episode.isEmpty {
            items.append(URLQueryItem(name: "episode", value: episode))
        }
        return try makeURL(path: "/search/episodes", queryItems: items, environment: environment)
    }

    static func tagsURL(tags: [String], environment: APIEnvironment = .current()) throws -> URL {
        let normalized = try normalizedTags(tags)
        return try makeURL(path: "/search/tag", queryItems: [
            URLQueryItem(name: "tags", value: normalized.joined(separator: ",")),
        ], environment: environment)
    }

    static func tagsURL(rawTags: String, environment: APIEnvironment = .current()) throws -> URL {
        try tagsURL(tags: normalizedTags(rawTags), environment: environment)
    }

    static func advancedConfigURL(source: String = defaultSource, environment: APIEnvironment = .current()) throws -> URL {
        try makeURL(path: "/search/adv/config", queryItems: [
            URLQueryItem(name: "source", value: source),
        ], environment: environment)
    }

    static func advancedSearchURL(
        query: SearchUpgradeAdvancedQuery,
        environment: APIEnvironment = .current()
    ) throws -> URL {
        try makeURL(path: "/search/adv", queryItems: query.queryItems, environment: environment)
    }

    static func makeURL(
        path: String,
        queryItems: [URLQueryItem],
        environment: APIEnvironment
    ) throws -> URL {
        guard let baseURL = environment.makeURL(path) else {
            throw APIError.invalidURL
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        return url
    }

    // MARK: - 校验 / 归一化

    static func requiredKeyword(_ keyword: String) throws -> String {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SearchUpgradeError.emptyKeyword
        }
        return trimmed
    }

    /// 英文逗号（兼容中文逗号）分隔；去重、去空白，最多 10 个。
    static func normalizedTags(_ rawTags: String) -> [String] {
        rawTags
            .components(separatedBy: CharacterSet(charactersIn: ",，"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func normalizedTags(_ tags: [String]) throws -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in tags {
            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(normalized)
        }
        guard !result.isEmpty else {
            throw SearchUpgradeError.emptyTags
        }
        guard result.count <= maxTagCount else {
            throw SearchUpgradeError.tooManyTags(max: maxTagCount)
        }
        return result
    }
}
