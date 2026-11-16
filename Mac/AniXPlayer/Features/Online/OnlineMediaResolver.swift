//
//  OnlineMediaResolver.swift
//  AniXPlayer
//
//  macOS：按 Animeko / Kazumi 规则搜索作品、解析剧集和视频直链。
//  逻辑对齐 Windows 版 OnlineMediaResolver，但 HTML 解析使用
//  Foundation XMLDocument + 自带的 CSS→XPath 转换。
//

import Foundation

final class OnlineMediaResolver {

    static let shared = OnlineMediaResolver()

    private init() {}

    // MARK: - Search

    func search(source: OnlineMediaSource, keyword: String) async throws -> [OnlineSubject] {
        let prepared = preparedKeyword(keyword, source: source)
        guard !prepared.isEmpty else { return [] }

        let template = source.searchURL
        let urlString: String
        if template.contains("{keyword}") {
            urlString = template.replacingOccurrences(of: "{keyword}", with: prepared)
        } else if template.contains("@keyword") {
            urlString = template.replacingOccurrences(of: "@keyword", with: prepared)
        } else {
            urlString = template
        }

        guard let url = URL(string: urlString), url.host != nil else {
            throw OnlinePlaybackError.invalidURL(urlString)
        }

        let response = try await OnlineHTTPClient.shared.get(
            url,
            headers: source.requestHeaders(pageURL: url)
        )
        let document = try OnlineHTMLDocument(
            html: response.text,
            baseURL: source.baseURL ?? response.finalURL
        )

        switch source.engine {
        case .animeko:
            return parseAnimekoSearch(source: source, document: document, response: response)
        case .kazumi:
            return parseKazumiSearch(source: source, document: document, response: response)
        }
    }

    private func parseAnimekoSearch(
        source: OnlineMediaSource,
        document: OnlineHTMLDocument,
        response: OnlineHTTPResponse
    ) -> [OnlineSubject] {
        let base = source.baseURL ?? response.finalURL
        var items: [(String, URL)] = []

        if source.subjectFormat == "indexed",
           !source.subjectSelectNames.isEmpty,
           !source.subjectSelectLinks.isEmpty {
            let nameNodes = document.elements(css: source.subjectSelectNames)
            let linkNodes = document.elements(css: source.subjectSelectLinks)
            for index in 0..<min(nameNodes.count, linkNodes.count) {
                let title = document.text(of: nameNodes[index])
                guard let href = document.href(of: linkNodes[index]) else { continue }
                items.append((title, href))
            }
        } else {
            let nodes = document.elements(css: source.subjectSelectLists)
            for node in nodes {
                let element = document.href(of: node) != nil
                    ? node
                    : document.elements(css: "a", in: node).first
                guard let element, let href = document.href(of: element) else { continue }
                var title = document.text(of: element)
                if title.isEmpty {
                    title = document.text(of: document.elements(css: "img", in: element).first)
                }
                items.append((title, href))
            }
        }

        // 按 URL 去重；preferShorterName 时取更短的标题。
        var byURL: [String: (String, URL)] = [:]
        for (title, url) in items {
            let key = url.absoluteString
            let value = title.isEmpty ? url.lastPathComponent : title
            if let existing = byURL[key] {
                if source.preferShorterName, value.count < existing.0.count {
                    byURL[key] = (value, url)
                }
            } else {
                byURL[key] = (value, url)
            }
        }

        return byURL.values
            .filter { !$0.0.isEmpty }
            .prefix(100)
            .map { OnlineSubject(source: source, title: $0.0, url: $0.1) }
    }

    private func parseKazumiSearch(
        source: OnlineMediaSource,
        document: OnlineHTMLDocument,
        response: OnlineHTTPResponse
    ) -> [OnlineSubject] {
        let containers = document.nodes(xpath: source.kazumiSearchList)
        var items: [(String, URL)] = []

        for container in containers {
            let nameNodes = document.nodes(xpath: source.kazumiSearchName, in: container)
            let linkNodes = document.nodes(xpath: source.kazumiSearchResult, in: container)
            let title = document.text(of: nameNodes.first)

            var href: URL?
            for node in linkNodes {
                guard let element = node as? XMLElement else { continue }
                if let value = document.href(of: element) {
                    href = value
                    break
                }
            }
            if href == nil, let element = container as? XMLElement {
                href = document.href(of: element)
            }

            guard let href else { continue }
            let value = title.isEmpty ? href.lastPathComponent : title
            items.append((value, href))
        }

        var seen = Set<String>()
        return items
            .filter { seen.insert($0.1.absoluteString).inserted && !$0.0.isEmpty }
            .prefix(100)
            .map { OnlineSubject(source: source, title: $0.0, url: $0.1) }
    }

    // MARK: - Episodes

    func loadEpisodes(source: OnlineMediaSource, subject: OnlineSubject) async throws -> [OnlineEpisode] {
        let response = try await OnlineHTTPClient.shared.get(
            subject.url,
            headers: source.requestHeaders(pageURL: subject.url)
        )
        let document = try OnlineHTMLDocument(
            html: response.text,
            baseURL: source.baseURL ?? response.finalURL
        )

        switch source.engine {
        case .animeko:
            return parseAnimekoEpisodes(source: source, document: document, pageURL: response.finalURL, subject: subject)
        case .kazumi:
            return parseKazumiEpisodes(source: source, document: document, pageURL: response.finalURL)
        }
    }

    private func parseAnimekoEpisodes(
        source: OnlineMediaSource,
        document: OnlineHTMLDocument,
        pageURL: URL,
        subject: OnlineSubject
    ) -> [OnlineEpisode] {
        var nodes: [XMLElement] = []

        if source.channelFormat == "index-grouped", !source.selectEpisodeLists.isEmpty {
            let lists = document.elements(css: source.selectEpisodeLists)
            for list in lists {
                nodes.append(contentsOf: document.elements(css: source.selectEpisodesFromList, in: list))
            }
        }

        if nodes.isEmpty, !source.selectEpisodes.isEmpty {
            nodes = document.elements(css: source.selectEpisodes)
        }

        // 有些规则把剧集直接放在作品页的所有链接里；只在规则选择器完全为空时兜底。
        if nodes.isEmpty, source.selectEpisodes.isEmpty, source.selectEpisodeLists.isEmpty {
            nodes = document.elements(css: "a")
        }

        return episodes(
            source: source,
            nodes: nodes,
            document: document,
            pageURL: pageURL,
            subject: subject
        )
    }

    private func parseKazumiEpisodes(
        source: OnlineMediaSource,
        document: OnlineHTMLDocument,
        pageURL: URL
    ) -> [OnlineEpisode] {
        var nodes: [XMLElement] = []
        let roads = document.nodes(xpath: source.kazumiChapterRoads)
        for road in roads {
            let result = document.nodes(xpath: source.kazumiChapterResult, in: road)
            nodes.append(contentsOf: result.compactMap { $0 as? XMLElement })
        }
        if nodes.isEmpty {
            nodes = document.nodes(xpath: source.kazumiChapterResult).compactMap { $0 as? XMLElement }
        }

        var items: [(String, URL)] = []
        for node in nodes {
            guard let href = document.href(of: node) else { continue }
            var title = document.text(of: node)
            // Kazumi 官方会去掉剧集名中的所有空白。
            title = title.replacingOccurrences(of: " ", with: "")
            if title.isEmpty {
                title = String(
                    format: NSLocalizedString("第 %d 集", comment: ""),
                    items.count + 1
                )
            }
            items.append((title, href))
        }

        var seen = Set<String>()
        let episodes = items
            .filter { seen.insert($0.1.absoluteString).inserted }
            .map { OnlineEpisode(
                title: $0.0,
                url: $0.1,
                sort: sortValue(from: $0.0)
            ) }

        return sortEpisodes(episodes)
    }

    private func episodes(
        source: OnlineMediaSource,
        nodes: [XMLElement],
        document: OnlineHTMLDocument,
        pageURL: URL,
        subject: OnlineSubject
    ) -> [OnlineEpisode] {
        var result: [OnlineEpisode] = []
        var seen = Set<String>()

        for node in nodes {
            guard let href = document.href(of: node) else { continue }
            var title = document.text(of: node)
            guard !title.isEmpty else { continue }
            guard isValidEpisodeTitle(title, href: href, pageURL: pageURL) else { continue }

            var sort: Double?
            if !source.matchEpisodeSortFromName.isEmpty {
                let matched = OnlineRegex.firstCapturedGroup(
                    pattern: source.matchEpisodeSortFromName,
                    group: "ep",
                    in: title
                )
                if let matched {
                    sort = numericValue(from: matched)
                } else {
                    // 规则要求按集数匹配；不匹配的链接多半是导航/广告。
                    if !source.showAllEpisodes {
                        continue
                    }
                    sort = sortValue(from: title)
                }
            } else {
                sort = sortValue(from: title)
            }

            guard seen.insert(href.absoluteString).inserted else { continue }
            result.append(OnlineEpisode(title: title, url: href, sort: sort))
        }

        return sortEpisodes(result)
    }

    private func sortEpisodes(_ episodes: [OnlineEpisode]) -> [OnlineEpisode] {
        let sorted = episodes.enumerated().sorted { lhs, rhs in
            let left = lhs.element.sort
            let right = rhs.element.sort
            if let left, let right, left != right {
                return left < right
            }
            if left != nil && right == nil { return true }
            if left == nil && right != nil { return false }
            return lhs.offset < rhs.offset
        }
        .map { $0.element }

        // 一个作品页常有多条线路，同一集会出现多次；UI 只显示一条，
        // 但保留其他线路地址，主线路播放失败时自动尝试备用线路。
        var order: [String] = []
        var groups: [String: [OnlineEpisode]] = [:]
        for episode in sorted {
            let key = episode.title
                .replacingOccurrences(of: " ", with: "")
                .lowercased()
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(episode)
        }

        return order.compactMap { key in
            guard let group = groups[key], let first = group.first else { return nil }
            return OnlineEpisode(
                title: first.title,
                url: first.url,
                sort: first.sort,
                alternateURLs: group.dropFirst().map(\.url)
            )
        }
    }

    // MARK: - Video URL

    func resolveMedia(source: OnlineMediaSource, episode: OnlineEpisode) async throws -> OnlineMediaMatch {
        var currentURL = episode.url
        var visited = Set<String>()

        for _ in 0..<4 {
            guard visited.insert(currentURL.absoluteString).inserted else { break }

            let response = try await OnlineHTTPClient.shared.get(
                currentURL,
                headers: source.requestHeaders(pageURL: currentURL)
            )
            let html = normalizedHTML(response.text)
            let base = source.baseURL ?? response.finalURL

            let videoPattern = source.matchVideoURL.isEmpty
                ? (source.isKazumi ? OnlineRegex.kazumiDefaultVideoPattern : "")
                : source.matchVideoURL

            if !videoPattern.isEmpty,
               let rawURL = OnlineRegex.firstURL(
                    pattern: videoPattern,
                    in: html,
                    preferLast: false
               ),
               let videoURL = OnlineHTMLDocument.absoluteURL(rawURL, baseURL: base) {
                return OnlineMediaMatch(
                    url: videoURL,
                    headers: source.videoHeaders(pageURL: currentURL),
                    pageURL: currentURL
                )
            }

            // 规则里的负向断言（例如 (?!.*http)）在整页 HTML 上可能过于严格，
            // 但页面里已经有明确的 .m3u8/.mp4 直链；按扩展名兜底扫描一次。
            if let rawURL = OnlineRegex.firstVideoURL(in: html),
               let videoURL = OnlineHTMLDocument.absoluteURL(rawURL, baseURL: base) {
                return OnlineMediaMatch(
                    url: videoURL,
                    headers: source.videoHeaders(pageURL: currentURL),
                    pageURL: currentURL
                )
            }

            // 没命中直链时跟随嵌套播放页/解析页。
            guard source.enableNestedURL,
                  !source.matchNestedURL.isEmpty,
                  let nested = OnlineRegex.firstURL(
                    pattern: source.matchNestedURL,
                    in: html,
                    preferLast: true
                  ),
                  let nestedURL = OnlineHTMLDocument.absoluteURL(nested, baseURL: base),
                  nestedURL.absoluteString != currentURL.absoluteString else {
                break
            }
            currentURL = nestedURL
        }

        throw OnlinePlaybackError.videoNotFound(episode.url)
    }

    // MARK: - Keyword

    private func preparedKeyword(_ raw: String, source: OnlineMediaSource) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.searchUseOnlyFirstWord {
            value = value.components(separatedBy: .whitespaces).first ?? value
        }
        if source.searchRemoveSpecial {
            value = String(value.filter { character in
                character.isLetter || character.isNumber || character == " "
            })
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }
        return value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }

    // MARK: - Helpers

    private func normalizedHTML(_ html: String) -> String {
        return html
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\u002F", with: "/")
    }

    private func numericValue(from string: String) -> Double? {
        let pattern = #"\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range, in: string) else {
            return nil
        }
        return Double(string[range])
    }

    private func sortValue(from title: String) -> Double? {
        return numericValue(from: title)
    }

    private func isValidEpisodeTitle(_ title: String, href: URL, pageURL: URL) -> Bool {
        let lowered = title.lowercased()
        let invalidWords = [
            "首页", "home", "返回", "上一页", "下一页", "更多", "查看更多",
            "展开", "收起", "广告", "推广", "赞助", "vip", "会员", "充值",
            "下载app", "客户端", "公告", "通知", "失效", "无效"
        ]
        if invalidWords.contains(where: { lowered == $0 || lowered.hasPrefix($0) }) {
            return false
        }
        if title.count == 1, !title.first!.isNumber {
            return false
        }
        if href.absoluteString == pageURL.absoluteString { return false }
        if let host = href.host, let pageHost = pageURL.host, host != pageHost {
            return true
        }
        return true
    }
}

// MARK: - Regex

enum OnlineRegex {

    static let kazumiDefaultVideoPattern = #"https?://[^\s"'<>\)]+?\.(m3u8|mp4)(\?[^\s"'<>\)]*)?"#

    /// 从规则匹配结果里取出真正的 URL。
    /// 优先命名分组 `v`；没有时从完整匹配中提取最后一个/第一个 http(s) URL。
    /// 这是为了兼容 `^.+(m3u8|vip).+\?` 这类会吞掉整段 HTML 的嵌套规则。
    static func firstURL(pattern: String, in text: String, preferLast: Bool) -> String? {
        guard !pattern.isEmpty, !text.isEmpty else { return nil }
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators, .anchorsMatchLines]
        ) else {
            return nil
        }

        let fullRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: fullRange) else {
            return nil
        }

        let namedRange = match.range(withName: "v")
        if namedRange.location != NSNotFound, let range = Range(namedRange, in: text) {
            return sanitizedURL(String(text[range]))
        }

        guard let matchRange = Range(match.range(at: 0), in: text) else { return nil }
        let matched = String(text[matchRange])
        let urls = urls(in: matched)
        let candidate = preferLast ? urls.last : urls.first
        return candidate.flatMap(sanitizedURL)
    }

    /// 从整页 HTML 中按扩展名挑选第一个视频直链，作为规则失败时的兜底。
    static func firstVideoURL(in text: String) -> String? {
        let candidates = urls(in: text).filter { raw in
            let path = raw.components(separatedBy: "?").first?.lowercased() ?? raw.lowercased()
            return path.hasSuffix(".m3u8")
                || path.hasSuffix(".mp4")
                || path.hasSuffix(".flv")
                || path.hasSuffix(".mkv")
        }
        guard !candidates.isEmpty else { return nil }

        // 优先级：m3u8 > mp4 > flv > mkv；同优先级按页面出现顺序取第一个。
        let priority: (String) -> Int = { raw in
            let path = raw.components(separatedBy: "?").first?.lowercased() ?? raw.lowercased()
            if path.hasSuffix(".m3u8") { return 0 }
            if path.hasSuffix(".mp4") { return 1 }
            if path.hasSuffix(".flv") { return 2 }
            return 3
        }
        return candidates.enumerated()
            .sorted { lhs, rhs in
                let left = priority(lhs.element)
                let right = priority(rhs.element)
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .first?
            .element
    }

    static func urls(in text: String) -> [String] {
        let pattern = #"https?://[^\s"'<>]+"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let stringRange = Range(match.range, in: text) else { return nil }
            return String(text[stringRange])
        }
    }

    private static func sanitizedURL(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'<>()[]{} ,;"))
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\/", with: "/")

        if value.hasPrefix("http%3A") || value.hasPrefix("https%3A"),
           let decoded = value.removingPercentEncoding {
            value = decoded
        }
        guard value.lowercased().hasPrefix("http") else { return nil }
        return value.isEmpty ? nil : value
    }

    /// 返回命名分组（不存在时回退到第 1 个分组/完整匹配）。
    static func firstCapturedGroup(pattern: String, group: String, in text: String) -> String? {
        guard !pattern.isEmpty, !text.isEmpty else { return nil }
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators, .anchorsMatchLines]
        ) else {
            return nil
        }

        let fullRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: fullRange) else {
            return nil
        }

        var range = match.range(withName: group)
        if range.location == NSNotFound {
            // 规则没有命名分组时使用完整匹配（与 Windows 版一致）。
            range = match.range(at: 0)
        }
        guard range.location != NSNotFound, let stringRange = Range(range, in: text) else {
            return nil
        }

        var value = String(text[stringRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        value = value
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'<>()[]{} ,;"))
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\/", with: "/")

        if value.hasPrefix("http%3A") || value.hasPrefix("https%3A"),
           let decoded = value.removingPercentEncoding {
            value = decoded
        }
        return value.isEmpty ? nil : value
    }
}
