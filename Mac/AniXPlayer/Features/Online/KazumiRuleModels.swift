//
//  KazumiRuleModels.swift
//  AniXPlayer
//
//  macOS：Kazumi 规则 JSON 的请求、搜索 API、选集 API 模型。
//
//  字段对齐 Kazumi（Predidit/Kazumi）的 api_rule_config.dart：
//  - searchMode / chapterMode 为 xpath 或 api；
//  - searchApiConfig 支持 GET/POST、query/JSON body、headers；
//  - chapterApiConfig 支持 nested（嵌套 JSON）与 delimited（分隔字符串）；
//  - sourceTemplate 为空时保留站点内部 source token，不伪造 URL。
//
//  单条规则解析失败只返回 skipped 原因，由 OnlineSourceStore 汇总，不影响其他源。
//

import Foundation

// MARK: - JSON value

/// 规则里的 headers/query/body 需要保留字符串、数字、布尔、数组和对象类型。
/// 统一成可 Equatable 的值，避免 `[String: Any]` 进入 OnlineMediaSource。
indirect enum KazumiJSONValue: Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([KazumiJSONValue])
    case object([String: KazumiJSONValue])

    static func from(_ value: Any?) -> KazumiJSONValue? {
        guard let value else { return nil }
        if value is NSNull { return .null }
        if let string = value as? String { return .string(string) }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            let type = String(cString: number.objCType)
            if type == "d" || type == "f" {
                return .double(number.doubleValue)
            }
            return .int(number.intValue)
        }
        if let array = value as? [Any] {
            return .array(array.map { KazumiJSONValue.from($0) ?? .null })
        }
        if let dictionary = value as? [String: Any] {
            var result: [String: KazumiJSONValue] = [:]
            for (key, item) in dictionary {
                result[key] = KazumiJSONValue.from(item) ?? .null
            }
            return .object(result)
        }
        return .string(String(describing: value))
    }

    static func dictionary(_ value: Any?) -> [String: KazumiJSONValue] {
        guard let raw = value as? [String: Any] else { return [:] }
        var result: [String: KazumiJSONValue] = [:]
        for (key, item) in raw {
            result[key] = KazumiJSONValue.from(item) ?? .null
        }
        return result
    }

    var stringValue: String {
        switch self {
        case .null:
            return ""
        case .bool(let value):
            return value ? "true" : "false"
        case .int(let value):
            return String(value)
        case .double(let value):
            if value.rounded() == value,
               value >= Double(Int.min),
               value <= Double(Int.max) {
                return String(Int(value))
            }
            return String(value)
        case .string(let value):
            return value
        case .array, .object:
            return ""
        }
    }

    var anyObject: Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .string(let value):
            return value
        case .array(let values):
            return values.map(\.anyObject)
        case .object(let values):
            var result: [String: Any] = [:]
            for (key, value) in values {
                result[key] = value.anyObject
            }
            return result
        }
    }
}

// MARK: - Template

enum KazumiTemplate {

    /// 与 Kazumi 的 `_renderTemplate` 一致：`@keyword` 前面不能紧贴字母/数字，
    /// 这样 `/GV@source` 也能正确替换。
    private static let placeholderRegex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_])@([A-Za-z_][A-Za-z0-9_]*)"#
    )

    private static let exactPlaceholderRegex = try! NSRegularExpression(
        pattern: #"^@([A-Za-z_][A-Za-z0-9_]*)$"#
    )

    static func render(
        _ template: String,
        variables: [String: KazumiJSONValue],
        encode: Bool
    ) throws -> String {
        guard !template.isEmpty else { return "" }

        let fullRange = NSRange(template.startIndex..., in: template)
        var result = ""
        var lastLocation = 0

        for match in placeholderRegex.matches(in: template, range: fullRange) {
            guard let wholeRange = Range(match.range(at: 0), in: template),
                  let nameRange = Range(match.range(at: 1), in: template) else {
                continue
            }
            let start = template.index(template.startIndex, offsetBy: lastLocation)
            result += String(template[start..<wholeRange.lowerBound])
            let name = String(template[nameRange])
            guard let value = variables[name] else {
                throw OnlinePlaybackError.unsupportedRule(String(
                    format: NSLocalizedString("规则模板缺少变量 @%@。", comment: ""),
                    name
                ))
            }
            result += encode ? percentEncode(value.stringValue) : value.stringValue
            lastLocation = template.distance(from: template.startIndex, to: wholeRange.upperBound)
        }

        result += String(template[template.index(template.startIndex, offsetBy: lastLocation)...])
        return result
    }

    static func renderValue(
        _ value: KazumiJSONValue,
        variables: [String: KazumiJSONValue]
    ) throws -> KazumiJSONValue {
        switch value {
        case .string(let string):
            if let name = exactPlaceholderName(in: string) {
                guard let replacement = variables[name] else {
                    throw OnlinePlaybackError.unsupportedRule(String(
                        format: NSLocalizedString("规则模板缺少变量 @%@。", comment: ""),
                        name
                    ))
                }
                return replacement
            }
            return .string(try render(string, variables: variables, encode: false))
        case .array(let values):
            return .array(try values.map { try renderValue($0, variables: variables) })
        case .object(let values):
            var result: [String: KazumiJSONValue] = [:]
            for (key, item) in values {
                result[key] = try renderValue(item, variables: variables)
            }
            return .object(result)
        default:
            return value
        }
    }

    static func percentEncode(_ value: String) -> String {
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func exactPlaceholderName(in value: String) -> String? {
        let range = NSRange(value.startIndex..., in: value)
        guard let match = exactPlaceholderRegex.firstMatch(in: value, range: range),
              let nameRange = Range(match.range(at: 1), in: value) else {
            return nil
        }
        return String(value[nameRange])
    }
}

// MARK: - Rule configs

struct KazumiRequestConfig: Equatable {
    let method: String
    let url: String
    let headers: [String: KazumiJSONValue]
    let query: [String: KazumiJSONValue]
    let bodyType: String
    let body: KazumiJSONValue?

    init(json: [String: Any]) {
        self.method = (json["method"] as? String ?? "GET")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        self.url = (json["url"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.headers = KazumiJSONValue.dictionary(json["headers"])
        self.query = KazumiJSONValue.dictionary(json["query"])
        self.bodyType = (json["bodyType"] as? String ?? "none")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if json.keys.contains("body") {
            self.body = KazumiJSONValue.from(json["body"])
        } else {
            self.body = nil
        }
    }
}

struct KazumiSearchAPIConfig: Equatable {
    let request: KazumiRequestConfig
    let listPath: String
    let namePath: String
    let sourcePath: String
    let sourceTemplate: String

    init(json: [String: Any]) {
        self.request = KazumiRequestConfig(
            json: json["request"] as? [String: Any] ?? [:]
        )
        self.listPath = (json["listPath"] as? String ?? "$.data[*]")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.namePath = (json["namePath"] as? String ?? "$.name")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourcePath = (json["sourcePath"] as? String ?? "$.url")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceTemplate = (json["sourceTemplate"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct KazumiEpisodePageConfig: Equatable {
    let url: String
    let query: [String: KazumiJSONValue]

    init(json: [String: Any]) {
        self.url = (json["url"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.query = KazumiJSONValue.dictionary(json["query"])
    }
}

struct KazumiChapterAPIConfig: Equatable {
    let request: KazumiRequestConfig
    let format: String
    let roadsPath: String
    let roadNamePath: String
    let episodesPath: String
    let episodeNamePath: String
    let episodeUrlPath: String
    let roadNamesPath: String
    let roadEpisodesPath: String
    let roadSeparator: String
    let episodeSeparator: String
    let fieldSeparator: String
    let variables: [String: String]
    let episodePage: KazumiEpisodePageConfig?

    init(json: [String: Any]) {
        self.request = KazumiRequestConfig(
            json: json["request"] as? [String: Any] ?? [:]
        )
        let rawFormat = (json["format"] as? String ?? "nested")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self.format = rawFormat == "delimited" ? "delimited" : "nested"
        self.roadsPath = (json["roadsPath"] as? String ?? "$.data.roads[*]")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.roadNamePath = (json["roadNamePath"] as? String ?? "$.name")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.episodesPath = (json["episodesPath"] as? String ?? "$.episodes[*]")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.episodeNamePath = (json["episodeNamePath"] as? String ?? "$.name")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.episodeUrlPath = (json["episodeUrlPath"] as? String ?? "$.url")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.roadNamesPath = (json["roadNamesPath"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.roadEpisodesPath = (json["roadEpisodesPath"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.roadSeparator = json["roadSeparator"] as? String ?? "$$$"
        self.episodeSeparator = json["episodeSeparator"] as? String ?? "#"
        self.fieldSeparator = json["fieldSeparator"] as? String ?? "$"

        var variables: [String: String] = [:]
        if let raw = json["variables"] as? [String: Any] {
            for (key, value) in raw {
                if let path = value as? String, !path.isEmpty {
                    variables[key] = path
                }
            }
        }
        self.variables = variables

        if let page = json["episodePage"] as? [String: Any],
           let pageURL = page["url"] as? String,
           !pageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.episodePage = KazumiEpisodePageConfig(json: page)
        } else {
            self.episodePage = nil
        }
    }
}

struct KazumiAPIProfile: Equatable {
    let searchMode: String
    let chapterMode: String
    let usePost: Bool
    let search: KazumiSearchAPIConfig?
    let chapter: KazumiChapterAPIConfig?

    var isSearchAPI: Bool { searchMode == "api" }
    var isChapterAPI: Bool { chapterMode == "api" }
}

// MARK: - Rule parsing

struct OnlineSkippedSourceRule: Equatable {
    let name: String
    let reason: String
}

enum KazumiRuleParseResult {
    case loaded(OnlineMediaSource)
    case skipped(name: String, reason: String)
}

enum KazumiRuleParser {

    static func parse(_ raw: [String: Any], index: Int) -> KazumiRuleParseResult {
        let name = string(raw["name"])
        guard !name.isEmpty else {
            return .skipped(
                name: NSLocalizedString("未命名规则", comment: ""),
                reason: NSLocalizedString("规则缺少名称。", comment: "")
            )
        }

        let searchMode = mode(raw["searchMode"])
        let chapterMode = mode(raw["chapterMode"])
        let usePost = bool(raw["usePost"])

        var searchAPI: KazumiSearchAPIConfig?
        if searchMode == "api" {
            guard let json = raw["searchApiConfig"] as? [String: Any] else {
                return .skipped(
                    name: name,
                    reason: NSLocalizedString("搜索模式为 API，但缺少 searchApiConfig。", comment: "")
                )
            }
            let config = KazumiSearchAPIConfig(json: json)
            guard !config.request.url.isEmpty else {
                return .skipped(
                    name: name,
                    reason: NSLocalizedString("搜索 API 配置缺少请求地址。", comment: "")
                )
            }
            guard !config.listPath.isEmpty else {
                return .skipped(
                    name: name,
                    reason: NSLocalizedString("搜索 API 配置缺少 listPath。", comment: "")
                )
            }
            do {
                try KazumiJSONPath.validate(config.listPath)
                if !config.namePath.isEmpty {
                    try KazumiJSONPath.validate(config.namePath)
                }
                if !config.sourcePath.isEmpty {
                    try KazumiJSONPath.validate(config.sourcePath)
                }
            } catch {
                return .skipped(name: name, reason: error.localizedDescription)
            }
            searchAPI = config
        } else {
            let searchURL = string(raw["searchURL"])
            guard !searchURL.isEmpty else {
                return .skipped(
                    name: name,
                    reason: NSLocalizedString("XPath 搜索规则缺少 searchURL。", comment: "")
                )
            }
            guard !string(raw["searchList"]).isEmpty else {
                return .skipped(
                    name: name,
                    reason: NSLocalizedString("XPath 搜索规则缺少 searchList。", comment: "")
                )
            }
            guard !string(raw["searchResult"]).isEmpty else {
                return .skipped(
                    name: name,
                    reason: NSLocalizedString("XPath 搜索规则缺少 searchResult。", comment: "")
                )
            }
        }

        var chapterAPI: KazumiChapterAPIConfig?
        if chapterMode == "api" {
            guard let json = raw["chapterApiConfig"] as? [String: Any] else {
                return .skipped(
                    name: name,
                    reason: NSLocalizedString("选集模式为 API，但缺少 chapterApiConfig。", comment: "")
                )
            }
            let config = KazumiChapterAPIConfig(json: json)
            guard !config.request.url.isEmpty else {
                return .skipped(
                    name: name,
                    reason: NSLocalizedString("选集 API 配置缺少请求地址。", comment: "")
                )
            }
            if config.format == "delimited" {
                guard !config.roadEpisodesPath.isEmpty else {
                    return .skipped(
                        name: name,
                        reason: NSLocalizedString("分隔选集配置缺少 roadEpisodesPath。", comment: "")
                    )
                }
                guard !config.roadSeparator.isEmpty,
                      !config.episodeSeparator.isEmpty,
                      !config.fieldSeparator.isEmpty else {
                    return .skipped(
                        name: name,
                        reason: NSLocalizedString("分隔选集配置的线路/剧集/字段分隔符不能为空。", comment: "")
                    )
                }
                do {
                    if !config.roadNamesPath.isEmpty {
                        try KazumiJSONPath.validate(config.roadNamesPath)
                    }
                    try KazumiJSONPath.validate(config.roadEpisodesPath)
                } catch {
                    return .skipped(name: name, reason: error.localizedDescription)
                }
            } else {
                guard !config.episodesPath.isEmpty else {
                    return .skipped(
                        name: name,
                        reason: NSLocalizedString("嵌套选集配置缺少 episodesPath。", comment: "")
                    )
                }
                guard !config.episodeUrlPath.isEmpty || config.episodePage != nil else {
                    return .skipped(
                        name: name,
                        reason: NSLocalizedString("嵌套选集配置缺少 episodeUrlPath 或 episodePage。", comment: "")
                    )
                }
                do {
                    if !config.roadsPath.isEmpty {
                        try KazumiJSONPath.validate(config.roadsPath)
                    }
                    if !config.roadNamePath.isEmpty {
                        try KazumiJSONPath.validate(config.roadNamePath)
                    }
                    try KazumiJSONPath.validate(config.episodesPath)
                    if !config.episodeNamePath.isEmpty {
                        try KazumiJSONPath.validate(config.episodeNamePath)
                    }
                    if !config.episodeUrlPath.isEmpty {
                        try KazumiJSONPath.validate(config.episodeUrlPath)
                    }
                    for path in config.variables.values {
                        try KazumiJSONPath.validate(path)
                    }
                } catch {
                    return .skipped(name: name, reason: error.localizedDescription)
                }
            }
            chapterAPI = config
        } else {
            guard !string(raw["chapterRoads"]).isEmpty else {
                return .skipped(
                    name: name,
                    reason: NSLocalizedString("XPath 选集规则缺少 chapterRoads。", comment: "")
                )
            }
            guard !string(raw["chapterResult"]).isEmpty else {
                return .skipped(
                    name: name,
                    reason: NSLocalizedString("XPath 选集规则缺少 chapterResult。", comment: "")
                )
            }
        }

        var detailParts: [String] = [NSLocalizedString("Kazumi 规则", comment: "")]
        let version = string(raw["version"])
        if !version.isEmpty {
            detailParts.append("v\(version)")
        }
        detailParts.append(searchMode == "api"
            ? NSLocalizedString("API 搜索", comment: "")
            : NSLocalizedString("XPath 搜索", comment: ""))
        detailParts.append(chapterMode == "api"
            ? NSLocalizedString("API 选集", comment: "")
            : NSLocalizedString("XPath 选集", comment: ""))

        var detail = detailParts.joined(separator: " · ")
        if antiCrawlerEnabled(raw["antiCrawlerConfig"]) {
            detail += NSLocalizedString(" · 站点有反爬验证，可能无法搜索", comment: "")
        }
        if searchMode == "api",
           chapterMode == "xpath",
           (searchAPI?.sourceTemplate.isEmpty ?? true) {
            detail += NSLocalizedString(" · 缺少详情页模板，XPath 选集不可用", comment: "")
        }

        let referer = string(raw["referer"]).nilIfEmpty
        let userAgent = string(raw["userAgent"])
        var videoHeaders: [String: String] = [:]
        if let referer {
            videoHeaders["Referer"] = referer
        }
        if !userAgent.isEmpty {
            videoHeaders["User-Agent"] = userAgent
        }

        let source = OnlineMediaSource(
            id: "kazumi:\(name)",
            engine: .kazumi,
            name: name,
            detail: detail,
            iconURL: nil,
            tier: 100 + index,
            searchURL: string(raw["searchURL"]),
            rawBaseURL: string(raw["baseURL"]).nilIfEmpty,
            searchUseOnlyFirstWord: false,
            searchRemoveSpecial: false,
            userAgent: userAgent.isEmpty ? OnlineHTTPClient.defaultUserAgent : userAgent,
            referer: referer,
            cookies: "",
            subjectFormat: "xpath",
            subjectSelectLists: "",
            subjectSelectNames: "",
            subjectSelectLinks: "",
            preferShorterName: false,
            channelFormat: "no-channel",
            selectEpisodeLists: "",
            selectEpisodesFromList: "",
            selectEpisodes: "",
            matchEpisodeSortFromName: "",
            showAllEpisodes: false,
            enableNestedURL: true,
            matchNestedURL: "",
            matchVideoURL: "",
            addHeadersToVideo: videoHeaders,
            kazumiSearchList: string(raw["searchList"]),
            kazumiSearchName: string(raw["searchName"]),
            kazumiSearchResult: string(raw["searchResult"]),
            kazumiChapterRoads: string(raw["chapterRoads"]),
            kazumiChapterResult: string(raw["chapterResult"]),
            kazumiAPI: KazumiAPIProfile(
                searchMode: searchMode,
                chapterMode: chapterMode,
                usePost: usePost,
                search: searchAPI,
                chapter: chapterAPI
            )
        )
        return .loaded(source)
    }

    // MARK: Helpers

    private static func string(_ value: Any?) -> String {
        guard let value else { return "" }
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return ""
    }

    private static func bool(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            return ["true", "1", "yes"].contains(string.lowercased())
        }
        return false
    }

    private static func mode(_ value: Any?) -> String {
        return string(value).lowercased() == "api" ? "api" : "xpath"
    }

    private static func antiCrawlerEnabled(_ value: Any?) -> Bool {
        guard let config = value as? [String: Any] else { return false }
        return bool(config["enabled"])
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
