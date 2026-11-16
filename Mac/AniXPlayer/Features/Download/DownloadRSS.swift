//
//  DownloadRSS.swift
//  AniXPlayer
//
//  macOS：RSS 2.0 / Atom 订阅、条目解析、自动下载筛选与持久化。
//  纯 Foundation 逻辑，不依赖 AppKit，直接编入单元测试 target。
//

import Foundation

// MARK: - Models

struct RSSFeedSubscription: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var url: String
    var isAutoDownloadEnabled: Bool
    var keywordFilters: [String]
    /// 已经出现在订阅里的条目 id。用于自动下载只处理“新条目”。
    var seenItemIDs: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        url: String,
        isAutoDownloadEnabled: Bool = false,
        keywordFilters: [String] = [],
        seenItemIDs: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.isAutoDownloadEnabled = isAutoDownloadEnabled
        self.keywordFilters = keywordFilters
        self.seenItemIDs = seenItemIDs
        self.createdAt = createdAt
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let host = URL(string: url)?.host, !host.isEmpty { return host }
        return url
    }

    func matches(title: String) -> Bool {
        RSSKeywordFilter.matches(title: title, keywords: keywordFilters)
    }
}

struct RSSFeedItem: Equatable, Identifiable {
    var id: String
    var title: String
    var linkURL: String?
    var enclosureURL: String?
    var publishedAt: Date?
    var sizeBytes: Int64?

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (manualDownloadURL ?? NSLocalizedString("未命名条目", comment: "")) : trimmed
    }

    /// 用户手动点击“下载”时优先使用 enclosure；没有时回退到 link。
    var manualDownloadURL: String? {
        httpURL(enclosureURL) ?? httpURL(linkURL)
    }

    /// 自动下载只用明确的 enclosure，避免把普通网页链接当成媒体文件。
    var autoDownloadURL: String? {
        httpURL(enclosureURL)
    }

    private func httpURL(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return raw
    }
}

struct RSSFeedParseResult: Equatable {
    var title: String?
    var items: [RSSFeedItem]
}

enum RSSFeedError: LocalizedError, Equatable {
    case invalidURL(String)
    case invalidXML(String)
    case network(String)
    case unsupportedFormat
    case httpStatus(Int)
    case responseTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return String(format: NSLocalizedString("RSS 地址无效：%@", comment: ""), value)
        case .invalidXML(let detail):
            return String(format: NSLocalizedString("RSS 解析失败：%@", comment: ""), detail)
        case .network(let detail):
            return String(format: NSLocalizedString("RSS 获取失败：%@", comment: ""), detail)
        case .unsupportedFormat:
            return NSLocalizedString("不是支持的 RSS 2.0 或 Atom 订阅。", comment: "")
        case .httpStatus(let status):
            return String(format: NSLocalizedString("RSS 服务器返回 HTTP %d", comment: ""), status)
        case .responseTooLarge:
            return NSLocalizedString("RSS 内容过大，已停止解析。", comment: "")
        }
    }
}

// MARK: - Keyword filters

enum RSSKeywordFilter {

    /// 支持英文/中文逗号、分号与换行分隔；去重并保留用户顺序。
    static func parse(_ raw: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",，;；\n")
        var seen = Set<String>()
        return raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
    }

    static func matches(title: String, keywords: [String]) -> Bool {
        let cleaned = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return true }
        return cleaned.contains { keyword in
            title.range(
                of: keyword,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: .current
            ) != nil
        }
    }
}

// MARK: - Auto download selection

enum RSSAutoDownload {

    /// 单次刷新最多自动添加的条目数，避免首次订阅时瞬间塞满下载队列。
    static let maximumItemsPerRefresh = 20

    static func itemsToAutoDownload(
        items: [RSSFeedItem],
        subscription: RSSFeedSubscription
    ) -> [RSSFeedItem] {
        guard subscription.isAutoDownloadEnabled else { return [] }
        let seen = Set(subscription.seenItemIDs)
        let matching = items.enumerated()
            .filter { _, item in
                !seen.contains(item.id)
                    && item.autoDownloadURL != nil
                    && subscription.matches(title: item.title)
            }
            .sorted { lhs, rhs in
                let left = lhs.element.publishedAt ?? .distantPast
                let right = rhs.element.publishedAt ?? .distantPast
                if left != right { return left > right }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
        return Array(matching.prefix(maximumItemsPerRefresh))
    }

    /// 刷新后把当前条目都记为已见；保留最近 `limit` 个，防止无限增长。
    static func updatedSeenItemIDs(
        existing: [String],
        items: [RSSFeedItem],
        limit: Int = 2_000
    ) -> [String] {
        var result = existing
        var seen = Set(existing)
        for item in items.reversed() where seen.insert(item.id).inserted {
            result.append(item.id)
        }
        if result.count > limit {
            result.removeFirst(result.count - limit)
        }
        return result
    }
}

// MARK: - Store

final class RSSFeedStore {

    static let shared = RSSFeedStore()

    static let defaultKey = "download.rss.feeds"

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard, key: String = RSSFeedStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func feeds() -> [RSSFeedSubscription] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RSSFeedSubscription].self, from: data) else {
            return []
        }
        return decoded
    }

    func save(_ feeds: [RSSFeedSubscription]) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(feeds) else { return }
        defaults.set(data, forKey: key)
    }
}

// MARK: - Service

final class RSSFeedService {

    static let shared = RSSFeedService()

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 40
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.httpShouldSetCookies = false
            self.session = URLSession(configuration: configuration)
        }
    }

    func fetch(feed: RSSFeedSubscription) async throws -> RSSFeedParseResult {
        try await fetch(urlString: feed.url)
    }

    func fetch(urlString: String) async throws -> RSSFeedParseResult {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            throw RSSFeedError.invalidURL(trimmed)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "AniXPlayer/macOS RSS",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RSSFeedError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw RSSFeedError.httpStatus(http.statusCode)
        }
        guard data.count <= 8 * 1024 * 1024 else {
            throw RSSFeedError.responseTooLarge
        }
        return try RSSFeedParser.parse(data: data)
    }
}

// MARK: - Parser

final class RSSFeedParser: NSObject, XMLParserDelegate {

    static func parse(data: Data) throws -> RSSFeedParseResult {
        guard !data.isEmpty else {
            throw RSSFeedError.invalidXML(NSLocalizedString("内容为空", comment: ""))
        }
        let delegate = RSSFeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            let detail = parser.parserError?.localizedDescription
                ?? NSLocalizedString("XML 格式错误", comment: "")
            throw RSSFeedError.invalidXML(detail)
        }
        guard delegate.sawRSSRoot || delegate.sawAtomRoot else {
            throw RSSFeedError.unsupportedFormat
        }
        return RSSFeedParseResult(
            title: delegate.feedTitle,
            items: delegate.items
        )
    }

    private struct ItemBuilder {
        var title = ""
        var linkURL: String?
        var enclosureURL: String?
        var guid: String?
        var publishedAt: Date?
        var sizeBytes: Int64?

        func build() -> RSSFeedItem? {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let link = linkURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            let enclosure = enclosureURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty
                    || (link?.isEmpty == false)
                    || (enclosure?.isEmpty == false) else {
                return nil
            }

            let identifier: String
            if let guid = guid?.trimmingCharacters(in: .whitespacesAndNewlines), !guid.isEmpty {
                identifier = "guid:" + guid
            } else if let link, !link.isEmpty {
                identifier = "link:" + link
            } else if let enclosure, !enclosure.isEmpty {
                identifier = "enclosure:" + enclosure
            } else {
                let stamp = publishedAt?.timeIntervalSince1970 ?? 0
                identifier = "title:\(trimmedTitle)#\(stamp)"
            }

            return RSSFeedItem(
                id: identifier,
                title: trimmedTitle,
                linkURL: link?.isEmpty == false ? link : nil,
                enclosureURL: enclosure?.isEmpty == false ? enclosure : nil,
                publishedAt: publishedAt,
                sizeBytes: sizeBytes
            )
        }
    }

    private(set) var items: [RSSFeedItem] = []
    private(set) var feedTitle: String?
    private(set) var sawRSSRoot = false
    private(set) var sawAtomRoot = false

    private var insideChannel = false
    private var insideItem = false
    private var current = ItemBuilder()
    private var currentText = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""
        let name = Self.normalized(elementName)

        switch name {
        case "rss":
            sawRSSRoot = true
        case "feed":
            sawAtomRoot = true
        case "channel":
            insideChannel = true
        case "item", "entry":
            insideItem = true
            current = ItemBuilder()
        case "enclosure":
            guard insideItem else { return }
            if let url = Self.attribute(attributeDict, "url"), !url.isEmpty {
                current.enclosureURL = url
            }
            if let length = Self.attribute(attributeDict, "length"),
               let bytes = Int64(length), bytes > 0 {
                current.sizeBytes = bytes
            }
        case "link":
            guard insideItem else { return }
            guard let href = Self.attribute(attributeDict, "href"), !href.isEmpty else {
                return
            }
            let rel = (Self.attribute(attributeDict, "rel") ?? "alternate").lowercased()
            if rel == "enclosure" {
                current.enclosureURL = href
                if let length = Self.attribute(attributeDict, "length"),
                   let bytes = Int64(length), bytes > 0 {
                    current.sizeBytes = bytes
                }
            } else if rel == "alternate" || rel.isEmpty {
                current.linkURL = href
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let value = String(data: CDATABlock, encoding: .utf8) {
            currentText += value
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = Self.normalized(elementName)
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "channel":
            insideChannel = false
        case "item", "entry":
            if let item = current.build() {
                items.append(item)
            }
            insideItem = false
            current = ItemBuilder()
        case "title":
            if insideItem {
                current.title = text
            } else if sawRSSRoot, insideChannel, feedTitle == nil {
                feedTitle = text.isEmpty ? nil : text
            } else if sawAtomRoot, feedTitle == nil {
                feedTitle = text.isEmpty ? nil : text
            }
        case "link":
            if insideItem, current.linkURL == nil, !text.isEmpty {
                current.linkURL = text
            }
        case "guid", "id":
            if insideItem, !text.isEmpty {
                current.guid = text
            }
        case "pubdate", "published", "updated":
            if insideItem, let date = Self.parseDate(text) {
                if current.publishedAt == nil || name == "published" {
                    current.publishedAt = date
                }
            }
        default:
            break
        }

        currentText = ""
    }

    // MARK: Helpers

    private static func normalized(_ elementName: String) -> String {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        return name.lowercased()
    }

    private static func attribute(_ attributes: [String: String], _ key: String) -> String? {
        if let value = attributes[key] { return value }
        return attributes.first { $0.key.lowercased() == key.lowercased() }?.value
    }

    private static func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }

        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
