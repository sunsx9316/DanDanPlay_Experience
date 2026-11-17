//
//  KazumiAPISupport.swift
//  AniXPlayer
//
//  macOS：Kazumi API 请求构造、JSON 搜索/选集解析与 URL 归一化。
//
//  只做规则声明的模板替换与 JSONPath 读取，不访问真实站点；
//  网络请求统一交给 OnlineHTTPClient。
//

import Foundation

// MARK: - URL

enum KazumiURL {

    /// baseURL 视为站点目录：没有末尾斜杠时补一个，已有则不重复。
    static func normalizedBase(_ base: URL?) -> URL? {
        guard let base,
              let scheme = base.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              base.host != nil,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        if components.path.isEmpty {
            components.path = "/"
        } else if !components.path.hasSuffix("/") {
            components.path += "/"
        }
        return components.url
    }

    static func resolve(_ raw: String, base: URL?) -> URL? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        // 模板对整个 @source 编码后可能得到 https%3A%2F%2F...；
        // 只在明确是编码后的协议/协议相对地址时还原，避免误改普通路径。
        let loweredEncoded = value.lowercased()
        if loweredEncoded.hasPrefix("http%3a")
            || loweredEncoded.hasPrefix("https%3a")
            || loweredEncoded.hasPrefix("%2f%2f"),
           let decoded = value.removingPercentEncoding {
            value = decoded
        }

        value = value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\/", with: "/")

        let lowered = value.lowercased()
        guard !lowered.hasPrefix("javascript:"),
              !lowered.hasPrefix("mailto:"),
              !lowered.hasPrefix("data:"),
              value != "#" else {
            return nil
        }

        if lowered.hasPrefix("//") {
            if let base {
                return validated(
                    URL(string: value, relativeTo: base)?.absoluteURL
                )
            }
            return validated(URL(string: "https:" + value))
        }

        if value.hasPrefix("?") {
            guard let base,
                  var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
                return nil
            }
            let queryAndFragment = value.dropFirst()
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            components.percentEncodedQuery = String(queryAndFragment[0])
            if queryAndFragment.count > 1 {
                components.percentEncodedFragment = String(queryAndFragment[1])
            }
            return validated(components.url)
        }

        if let absolute = URL(string: value),
           let scheme = absolute.scheme?.lowercased(),
           scheme == "http" || scheme == "https",
           absolute.host != nil {
            return absolute
        }

        guard let base = validated(base) else { return nil }
        return validated(
            URL(string: value, relativeTo: base)?.absoluteURL
        )
    }

    private static func validated(_ url: URL?) -> URL? {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return nil
        }
        return url
    }
}

// MARK: - Prepared request

struct KazumiPreparedRequest {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data?
    let contentType: String?
}

enum KazumiAPIRequestBuilder {

    static func makeRequest(
        config: KazumiRequestConfig,
        variables: [String: KazumiJSONValue],
        baseHeaders: [String: String] = [:],
        baseURL: URL?
    ) throws -> KazumiPreparedRequest {
        let method = config.method.uppercased()
        guard method == "GET" || method == "POST" else {
            throw OnlinePlaybackError.unsupportedRule(String(
                format: NSLocalizedString("API 规则只支持 GET/POST，当前为 %@。", comment: ""),
                method
            ))
        }
        guard !config.url.isEmpty else {
            throw OnlinePlaybackError.unsupportedRule(
                NSLocalizedString("API 请求地址为空。", comment: "")
            )
        }

        let renderedURL = try KazumiTemplate.render(
            config.url,
            variables: variables,
            encode: true
        )
        guard var components = URLComponents(string: renderedURL) else {
            throw OnlinePlaybackError.invalidURL(renderedURL)
        }

        // 相对请求地址允许通过 baseURL / 搜索页 origin 补全。
        if components.scheme == nil || components.host == nil {
            guard let resolved = KazumiURL.resolve(renderedURL, base: baseURL),
                  let resolvedComponents = URLComponents(
                    url: resolved,
                    resolvingAgainstBaseURL: false
                  ) else {
                throw OnlinePlaybackError.invalidURL(renderedURL)
            }
            components = resolvedComponents
        }
        guard let url = components.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            throw OnlinePlaybackError.invalidURL(renderedURL)
        }

        if !config.query.isEmpty {
            var items = components.queryItems ?? []
            for key in config.query.keys.sorted() {
                guard let value = config.query[key] else { continue }
                let name = try KazumiTemplate.render(key, variables: variables, encode: false)
                let rendered = try KazumiTemplate.render(
                    value.stringValue,
                    variables: variables,
                    encode: false
                )
                items.removeAll { $0.name == name }
                items.append(URLQueryItem(name: name, value: rendered))
            }
            components.queryItems = items
        }

        guard let finalURL = components.url else {
            throw OnlinePlaybackError.invalidURL(renderedURL)
        }

        var headers = baseHeaders
        for key in config.headers.keys.sorted() {
            guard let value = config.headers[key] else { continue }
            let name = try KazumiTemplate.render(key, variables: variables, encode: false)
            let rendered = try KazumiTemplate.render(
                value.stringValue,
                variables: variables,
                encode: false
            )
            headers[name] = rendered
        }

        var body: Data?
        var contentType: String?

        if method == "POST", config.bodyType != "none", let bodyValue = config.body {
            let renderedBody = try KazumiTemplate.renderValue(
                bodyValue,
                variables: variables
            )
            switch config.bodyType {
            case "json":
                body = try JSONSerialization.data(
                    withJSONObject: renderedBody.anyObject,
                    options: [.fragmentsAllowed]
                )
                contentType = "application/json; charset=utf-8"
            case "form":
                body = formBody(from: renderedBody).data(using: .utf8)
                contentType = "application/x-www-form-urlencoded; charset=utf-8"
            default:
                body = nil
            }
        }

        if let contentType,
           !headers.keys.contains(where: { $0.lowercased() == "content-type" }) {
            headers["Content-Type"] = contentType
        }
        if !headers.keys.contains(where: { $0.lowercased() == "accept" }) {
            headers["Accept"] = "application/json, text/plain, */*"
        }

        return KazumiPreparedRequest(
            method: method,
            url: finalURL,
            headers: headers,
            body: body,
            contentType: contentType
        )
    }

    private static func formBody(from value: KazumiJSONValue) -> String {
        switch value {
        case .object(let object):
            var components = URLComponents()
            components.queryItems = object.keys.sorted().map { key in
                URLQueryItem(name: key, value: object[key]?.stringValue ?? "")
            }
            return components.percentEncodedQuery ?? ""
        case .string(let string):
            return string
        case .null:
            return ""
        default:
            return value.stringValue
        }
    }
}

// MARK: - Search

struct KazumiAPISearchItem {
    let name: String
    let source: String
    let url: URL?
}

enum KazumiAPISearchParser {

    /// sourceTemplate 为空时，允许从搜索结果里读取这些明确的 URL 字段；
    /// 不会用 baseURL + ID 猜测详情页。
    private static let urlFieldNames = [
        "url", "link", "href", "detailUrl", "detail_url", "detailURL",
        "sourceUrl", "source_url", "webUrl", "web_url", "playUrl", "play_url"
    ]

    static func parse(
        text: String,
        config: KazumiSearchAPIConfig,
        baseURL: URL?
    ) throws -> [KazumiAPISearchItem] {
        let document = try jsonDocument(text: text, kind: NSLocalizedString("搜索 API", comment: ""))
        let nodes = try KazumiJSONPath.read(document, path: config.listPath)

        var items: [KazumiAPISearchItem] = []
        for node in nodes {
            let name = KazumiJSONPath.stringValue(
                try? KazumiJSONPath.first(in: node, path: config.namePath)
            )
            let source = KazumiJSONPath.stringValue(
                try? KazumiJSONPath.first(in: node, path: config.sourcePath)
            )
            guard !name.isEmpty else { continue }

            let url = try detailURL(
                node: node,
                source: source,
                config: config,
                baseURL: baseURL
            )
            guard !source.isEmpty || url != nil else { continue }

            items.append(KazumiAPISearchItem(name: name, source: source, url: url))
            if items.count >= 100 { break }
        }
        return items
    }

    private static func detailURL(
        node: Any,
        source: String,
        config: KazumiSearchAPIConfig,
        baseURL: URL?
    ) throws -> URL? {
        let template = config.sourceTemplate
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !template.isEmpty {
            guard !source.isEmpty else { return nil }
            if template == "@source" {
                return KazumiURL.resolve(source, base: baseURL)
            }
            let rendered = try KazumiTemplate.render(
                template,
                variables: ["source": .string(source)],
                encode: true
            )
            return KazumiURL.resolve(rendered, base: baseURL)
        }

        // sourcePath 本身可能直接返回 URL/根相对路径。
        if looksLikeURLValue(source) {
            return KazumiURL.resolve(source, base: baseURL)
        }

        // 规则没有 sourceTemplate 时，先尝试搜索结果自带的 URL 字段。
        for key in urlFieldNames {
            let value = try? KazumiJSONPath.first(in: node, path: "$['\(key)']")
            let raw = KazumiJSONPath.stringValue(value)
            guard looksLikeURLFieldValue(raw),
                  let url = KazumiURL.resolve(raw, base: baseURL) else {
                continue
            }
            return url
        }

        return nil
    }

    private static func looksLikeURLValue(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        let lowered = value.lowercased()
        return lowered.hasPrefix("http://")
            || lowered.hasPrefix("https://")
            || lowered.hasPrefix("//")
            || value.hasPrefix("/")
            || value.hasPrefix("./")
            || value.hasPrefix("../")
    }

    /// URL 字段也可能是相对路径；只接受看起来像路径的值，
    /// 避免把裸 ID（例如 "42"）拼成 baseURL/42。
    private static func looksLikeURLFieldValue(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        if looksLikeURLValue(value) { return true }
        let lowered = value.lowercased()
        return value.contains("/")
            || value.contains("?")
            || lowered.hasSuffix(".html")
            || lowered.hasSuffix(".htm")
    }

    private static func jsonDocument(text: String, kind: String) throws -> Any {
        guard let data = text.data(using: .utf8) else {
            throw OnlinePlaybackError.emptyResponse
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw OnlinePlaybackError.unsupportedRule(String(
                format: NSLocalizedString("%@ 返回的不是有效 JSON。", comment: ""),
                kind
            ))
        }
    }
}

// MARK: - Chapters

enum KazumiAPIChapterParser {

    static func parse(
        text: String,
        config: KazumiChapterAPIConfig,
        source: String,
        baseURL: URL?
    ) throws -> [OnlineEpisode] {
        guard let data = text.data(using: .utf8) else {
            throw OnlinePlaybackError.emptyResponse
        }
        let document: Any
        do {
            document = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw OnlinePlaybackError.unsupportedRule(
                NSLocalizedString("选集 API 返回的不是有效 JSON。", comment: "")
            )
        }

        var variables: [String: KazumiJSONValue] = ["source": .string(source)]
        for (key, path) in config.variables {
            guard let value = try KazumiJSONPath.first(in: document, path: path) else {
                throw OnlinePlaybackError.unsupportedRule(String(
                    format: NSLocalizedString("选集 API 的变量 %@ 未匹配到值。", comment: ""),
                    key
                ))
            }
            variables[key] = KazumiJSONValue.from(value) ?? .string(KazumiJSONPath.stringValue(value))
        }

        if config.format == "delimited" {
            return try parseDelimited(
                document: document,
                config: config,
                variables: variables,
                baseURL: baseURL
            )
        }
        return try parseNested(
            document: document,
            config: config,
            variables: variables,
            baseURL: baseURL
        )
    }

    private static func parseNested(
        document: Any,
        config: KazumiChapterAPIConfig,
        variables: [String: KazumiJSONValue],
        baseURL: URL?
    ) throws -> [OnlineEpisode] {
        let roads = config.roadsPath.isEmpty
            ? [document]
            : try KazumiJSONPath.read(document, path: config.roadsPath)

        var episodes: [OnlineEpisode] = []
        for (roadIndex, road) in roads.enumerated() {
            let roadName: String?
            if config.roadsPath.isEmpty || config.roadNamePath.isEmpty {
                roadName = nil
            } else {
                let value = KazumiJSONPath.stringValue(
                    try? KazumiJSONPath.first(in: road, path: config.roadNamePath)
                )
                roadName = value.isEmpty ? nil : value
            }

            let nodes: [Any]
            do {
                nodes = try KazumiJSONPath.read(road, path: config.episodesPath)
            } catch {
                // 单条线路解析失败只跳过该线路。
                continue
            }

            for (episodeIndex, node) in nodes.enumerated() {
                let name = KazumiJSONPath.stringValue(
                    try? KazumiJSONPath.first(in: node, path: config.episodeNamePath)
                )
                let rawURL = config.episodeUrlPath.isEmpty
                    ? ""
                    : KazumiJSONPath.stringValue(
                        try? KazumiJSONPath.first(in: node, path: config.episodeUrlPath)
                    )

                guard let pageURL = try resolveEpisodeURL(
                    config: config,
                    variables: variables,
                    rawURL: rawURL,
                    roadIndex: roadIndex,
                    episodeIndex: episodeIndex,
                    baseURL: baseURL
                ) else {
                    continue
                }

                let title = name.isEmpty
                    ? String(format: NSLocalizedString("第 %d 集", comment: ""), episodeIndex + 1)
                    : name
                episodes.append(OnlineEpisode(
                    title: title,
                    url: pageURL,
                    sort: nil,
                    alternateURLs: [],
                    roadName: roadName
                ))
            }
        }
        return episodes
    }

    private static func parseDelimited(
        document: Any,
        config: KazumiChapterAPIConfig,
        variables: [String: KazumiJSONValue],
        baseURL: URL?
    ) throws -> [OnlineEpisode] {
        let roadNames: [String]
        if config.roadNamesPath.isEmpty {
            roadNames = []
        } else {
            let value = KazumiJSONPath.stringValue(
                try? KazumiJSONPath.first(in: document, path: config.roadNamesPath)
            )
            roadNames = split(value, separator: config.roadSeparator)
        }

        let episodesValue = KazumiJSONPath.stringValue(
            try? KazumiJSONPath.first(in: document, path: config.roadEpisodesPath)
        )
        guard !episodesValue.isEmpty else { return [] }

        let roadGroups = split(episodesValue, separator: config.roadSeparator)
        var episodes: [OnlineEpisode] = []

        for (roadIndex, group) in roadGroups.enumerated() {
            let configuredRoadName = roadIndex < roadNames.count
                ? roadNames[roadIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            let roadName = configuredRoadName.isEmpty ? nil : configuredRoadName
            let entries = split(group, separator: config.episodeSeparator)
            for (episodeIndex, rawEntry) in entries.enumerated() {
                let entry = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !entry.isEmpty,
                      let separatorRange = entry.range(of: config.fieldSeparator) else {
                    continue
                }
                let name = String(entry[..<separatorRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let rawURL = String(entry[separatorRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard let pageURL = try resolveEpisodeURL(
                    config: config,
                    variables: variables,
                    rawURL: rawURL,
                    roadIndex: roadIndex,
                    episodeIndex: episodeIndex,
                    baseURL: baseURL
                ) else {
                    continue
                }

                let title = name.isEmpty
                    ? String(format: NSLocalizedString("第 %d 集", comment: ""), episodeIndex + 1)
                    : name
                episodes.append(OnlineEpisode(
                    title: title,
                    url: pageURL,
                    sort: nil,
                    alternateURLs: [],
                    roadName: roadName
                ))
            }
        }
        return episodes
    }

    private static func resolveEpisodeURL(
        config: KazumiChapterAPIConfig,
        variables: [String: KazumiJSONValue],
        rawURL: String,
        roadIndex: Int,
        episodeIndex: Int,
        baseURL: URL?
    ) throws -> URL? {
        guard let page = config.episodePage else {
            return KazumiURL.resolve(rawURL, base: baseURL)
        }

        var localVariables = variables
        localVariables["episodeUrl"] = .string(rawURL)
        localVariables["roadIndex"] = .int(roadIndex)
        localVariables["roadNumber"] = .int(roadIndex + 1)
        localVariables["episodeIndex"] = .int(episodeIndex)
        localVariables["episodeNumber"] = .int(episodeIndex + 1)

        let pageTemplate = page.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let renderedURL: String
        if pageTemplate == "@episodeUrl" {
            // 模板本身就是完整地址时不能再做整体百分号编码。
            renderedURL = rawURL
        } else {
            renderedURL = try KazumiTemplate.render(
                pageTemplate,
                variables: localVariables,
                encode: true
            )
        }
        guard var components = URLComponents(string: renderedURL) else {
            throw OnlinePlaybackError.invalidURL(renderedURL)
        }
        if components.scheme == nil || components.host == nil {
            guard let resolved = KazumiURL.resolve(renderedURL, base: baseURL),
                  let resolvedComponents = URLComponents(
                    url: resolved,
                    resolvingAgainstBaseURL: false
                  ) else {
                throw OnlinePlaybackError.invalidURL(renderedURL)
            }
            components = resolvedComponents
        }

        if !page.query.isEmpty {
            var items = components.queryItems ?? []
            for key in page.query.keys.sorted() {
                guard let value = page.query[key] else { continue }
                let name = try KazumiTemplate.render(key, variables: localVariables, encode: false)
                let rendered = try KazumiTemplate.render(
                    value.stringValue,
                    variables: localVariables,
                    encode: false
                )
                items.removeAll { $0.name == name }
                items.append(URLQueryItem(name: name, value: rendered))
            }
            components.queryItems = items
        }

        return KazumiURL.resolve(components.string ?? renderedURL, base: baseURL)
    }

    private static func split(_ value: String, separator: String) -> [String] {
        guard !separator.isEmpty else { return value.isEmpty ? [] : [value] }
        return value.components(separatedBy: separator)
    }
}
