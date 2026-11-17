//
//  OnlineSourceModels.swift
//  AniXPlayer
//
//  macOS：在线观看的源配置、搜索结果与解析结果模型。
//  字段对齐 Windows 版 AcplayWPFClient/Pages/Welcome/OnlinePlayer 的
//  OnlineMediaSource / OnlineMediaResolver，但不内置任何第三方源。
//

import Foundation

// MARK: - Engine

enum OnlineSourceEngine: String, CaseIterable, Codable {
    case animeko
    case kazumi

    var displayName: String {
        switch self {
        case .animeko:
            return "Animeko"
        case .kazumi:
            return "Kazumi"
        }
    }
}

// MARK: - Source

/// 一个可搜索的在线媒体源。
///
/// Animeko 与 Kazumi 的规则字段差异较大，这里统一成同一结构；
/// 未使用的字段保持为空，由 `OnlineMediaResolver` 按 engine 分支读取。
struct OnlineMediaSource: Identifiable, Equatable {

    let id: String
    let engine: OnlineSourceEngine
    let name: String
    let detail: String
    let iconURL: URL?
    let tier: Int

    /// 搜索 URL 模板。Animeko 使用 `{keyword}`，Kazumi 使用 `@keyword`。
    let searchURL: String
    let rawBaseURL: String?
    let searchUseOnlyFirstWord: Bool
    let searchRemoveSpecial: Bool
    let userAgent: String
    /// Kazumi 规则里的参考页；Animeko 通常为空，运行时用站点 origin。
    let referer: String?
    /// 形如 `quality=1080`，会写入 Cookie 请求头。
    let cookies: String

    // Animeko 搜索结果选择器
    let subjectFormat: String
    let subjectSelectLists: String
    let subjectSelectNames: String
    let subjectSelectLinks: String
    /// Animeko `subjectFormatId == "jsonpath"` 时的 JSONPath 选择器。
    /// 路径作用于搜索接口返回的 JSON；为空时该规则无法使用 JSONPath 搜索。
    let subjectJSONPathNames: String
    let subjectJSONPathLinks: String
    let preferShorterName: Bool

    // Animeko 剧集选择器
    let channelFormat: String
    /// index-grouped 时与 selectEpisodeLists 一一对应的频道名选择器。
    let selectChannelNames: String
    /// 规则提供的频道名过滤正则；为空表示不过滤。
    let matchChannelName: String
    let selectEpisodeLists: String
    let selectEpisodesFromList: String
    let selectEpisodes: String
    let matchEpisodeSortFromName: String
    let showAllEpisodes: Bool

    // 视频地址解析
    let enableNestedURL: Bool
    let matchNestedURL: String
    let matchVideoURL: String
    let addHeadersToVideo: [String: String]

    // Kazumi XPath 规则
    let kazumiSearchList: String
    let kazumiSearchName: String
    let kazumiSearchResult: String
    let kazumiChapterRoads: String
    let kazumiChapterResult: String

    /// Kazumi API 模式配置；nil 表示纯 XPath 规则（或 Animeko 源）。
    /// 使用 var + 默认值让既有 Animeko 构造调用无需改动。
    var kazumiAPI: KazumiAPIProfile? = nil

    var isKazumi: Bool {
        return engine == .kazumi
    }

    var baseURL: URL? {
        guard let rawBaseURL,
              let url = URL(string: rawBaseURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return nil
        }
        return KazumiURL.normalizedBase(url) ?? url
    }

    /// 搜索/剧集页请求使用的基础请求头。
    func requestHeaders(pageURL: URL? = nil) -> [String: String] {
        var headers: [String: String] = [:]
        if !userAgent.isEmpty {
            headers["User-Agent"] = userAgent
        }
        if let referer, !referer.isEmpty {
            headers["Referer"] = referer
        } else if let baseURL {
            headers["Referer"] = baseURL.absoluteString
        } else if let pageURL, let scheme = pageURL.scheme, let host = pageURL.host {
            headers["Referer"] = "\(scheme)://\(host)/"
        }
        if !cookies.isEmpty {
            headers["Cookie"] = cookies
        }
        return headers
    }

    /// 解析到视频地址后交给播放器的请求头。
    func videoHeaders(pageURL: URL) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in addHeadersToVideo {
            let normalized = OnlineMediaSource.normalizedHeaderName(key)
            if !normalized.isEmpty, !value.isEmpty {
                headers[normalized] = value
            }
        }
        if headers["User-Agent"] == nil, !userAgent.isEmpty {
            headers["User-Agent"] = userAgent
        }
        if headers["Referer"] == nil {
            if let referer, !referer.isEmpty {
                headers["Referer"] = referer
            } else if let baseURL {
                headers["Referer"] = baseURL.absoluteString
            } else if let scheme = pageURL.scheme, let host = pageURL.host {
                headers["Referer"] = "\(scheme)://\(host)/"
            }
        }
        if headers["Cookie"] == nil, !cookies.isEmpty {
            headers["Cookie"] = cookies
        }
        return headers
    }

    static func normalizedHeaderName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "referer", "referrer":
            return "Referer"
        case "useragent", "user-agent":
            return "User-Agent"
        case "cookie":
            return "Cookie"
        case "origin":
            return "Origin"
        case "accept":
            return "Accept"
        case "accept-language":
            return "Accept-Language"
        default:
            return raw
        }
    }
}

// MARK: - Search / episode

struct OnlineSubject: Identifiable, Equatable {
    let id: String
    let sourceID: String
    let sourceName: String
    let engine: OnlineSourceEngine
    let tier: Int
    let title: String
    /// 作品详情页地址。API 规则 sourceTemplate 为空时可能为 nil。
    let url: URL?
    /// 站点内部 ID/令牌；API 选集请求的 `@source` 使用它。
    let sourceToken: String?

    init(source: OnlineMediaSource, title: String, url: URL?, sourceToken: String? = nil) {
        let token = sourceToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedToken = (token?.isEmpty == false) ? token : nil
        let identity: String
        if let url {
            identity = url.absoluteString
        } else if let normalizedToken {
            identity = "token:\(normalizedToken)"
        } else {
            identity = "title:\(title)"
        }
        self.id = "\(source.id)|\(identity)"
        self.sourceID = source.id
        self.sourceName = source.name
        self.engine = source.engine
        self.tier = source.tier
        self.title = title
        self.url = url
        self.sourceToken = normalizedToken
    }

    /// 合并搜索结果时用于去重；token-only 条目不会伪造 URL。
    var identityKey: String {
        if let url {
            return url.absoluteString
        }
        if let sourceToken {
            return "\(sourceID)|token:\(sourceToken)"
        }
        return "\(sourceID)|title:\(title)"
    }
}

struct OnlineEpisode: Identifiable, Equatable {
    let id: String
    let title: String
    let url: URL
    /// 从标题里提取出的集数，用于排序；无法提取时为 nil。
    let sort: Double?
    /// 同一集在其他线路的页面地址；主线路解析失败时依次尝试。
    let alternateURLs: [URL]
    /// API 选集返回的线路名称；XPath 规则通常为 nil。
    let roadName: String?

    init(
        title: String,
        url: URL,
        sort: Double?,
        alternateURLs: [URL] = [],
        roadName: String? = nil
    ) {
        self.id = url.absoluteString
        self.title = title
        self.url = url
        self.sort = sort
        self.alternateURLs = alternateURLs
        self.roadName = roadName
    }
}

struct OnlineMediaMatch {
    let url: URL
    let headers: [String: String]
    let pageURL: URL
}

struct OnlineSearchOutcome {
    let subjects: [OnlineSubject]
    /// 单个源失败不影响整体；这里保留失败原因用于 UI 提示。
    let failures: [String: String]
    let sourceCount: Int
}

// MARK: - Errors

enum OnlinePlaybackError: LocalizedError {
    case noSources
    case invalidURL(String)
    case httpStatus(Int, URL)
    case responseTooLarge
    case emptyResponse
    case htmlParseFailed
    case sourceNotFound
    case videoNotFound(URL)
    case streamUnavailable(Int, URL)
    case unsupportedRule(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noSources:
            return NSLocalizedString("没有可用的在线源，请在源管理中更新源配置。", comment: "")
        case .invalidURL(let value):
            return String(format: NSLocalizedString("无效的地址：%@", comment: ""), value)
        case .httpStatus(let code, let url):
            return String(
                format: NSLocalizedString("请求失败（HTTP %d）：%@", comment: ""),
                code,
                url.absoluteString
            )
        case .responseTooLarge:
            return NSLocalizedString("页面内容过大，已停止解析。", comment: "")
        case .emptyResponse:
            return NSLocalizedString("源返回了空内容。", comment: "")
        case .htmlParseFailed:
            return NSLocalizedString("网页解析失败，可能不是标准 HTML。", comment: "")
        case .sourceNotFound:
            return NSLocalizedString("找不到对应的在线源，请刷新源配置。", comment: "")
        case .videoNotFound(let url):
            return String(
                format: NSLocalizedString("未能从剧集页解析出视频地址：%@", comment: ""),
                url.absoluteString
            )
        case .streamUnavailable(let status, let url):
            return String(
                format: NSLocalizedString("视频源不可用（HTTP %d），可能需要登录或防盗链。请换一个源。\n%@", comment: ""),
                status,
                url.absoluteString
            )
        case .unsupportedRule(let reason):
            return reason
        case .cancelled:
            return NSLocalizedString("已取消。", comment: "")
        }
    }
}
