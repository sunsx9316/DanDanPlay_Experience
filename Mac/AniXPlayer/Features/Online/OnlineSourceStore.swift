//
//  OnlineSourceStore.swift
//  AniXPlayer
//
//  macOS：Animeko / Kazumi 源配置的下载、缓存与解析。
//
//  缓存位置：Application Support/AniXPlayer/OnlineSources/
//  - animeko/css1.json
//  - kazumi/index.json + kazumi/rules/<name>.json
//
//  默认使用与 Windows 版相同的远端配置地址，但不随 App 内置任何第三方源；
//  用户可在“源管理”里改成自己的地址或清空缓存。
//

import Foundation

// MARK: - Preferences

enum OnlineSourcePreferences {

    private enum Key {
        static let animekoURL = "online.source.animekoURL"
        static let kazumiURL = "online.source.kazumiURL"
        static let disabledSources = "online.source.disabled"
        static let pinnedSources = "online.source.pinned"
        static let searchHistory = "online.source.searchHistory"
        static let dismissedCompliance = "online.source.dismissedCompliance"
        static let continuousPlayback = "online.playback.continuous"
    }

    /// Windows 版默认值；只作为可配置地址，不随 App 分发配置内容。
    static let defaultAnimekoURL = "https://sub.creamycake.org/v1/css1.json"
    static let defaultKazumiURL = "https://raw.githubusercontent.com/Predidit/KazumiRules/main"

    static var animekoURL: String {
        get {
            let value = UserDefaults.standard.string(forKey: Key.animekoURL)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty == false ? value! : defaultAnimekoURL)
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.animekoURL)
        }
    }

    static var kazumiURL: String {
        get {
            let value = UserDefaults.standard.string(forKey: Key.kazumiURL)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty == false ? value! : defaultKazumiURL)
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.kazumiURL)
        }
    }

    static func resetURLs() {
        UserDefaults.standard.removeObject(forKey: Key.animekoURL)
        UserDefaults.standard.removeObject(forKey: Key.kazumiURL)
    }

    static func isSourceEnabled(_ id: String) -> Bool {
        let values = UserDefaults.standard.stringArray(forKey: Key.disabledSources) ?? []
        return !values.contains(id)
    }

    static func setSource(_ id: String, enabled: Bool) {
        var values = UserDefaults.standard.stringArray(forKey: Key.disabledSources) ?? []
        if enabled {
            values.removeAll { $0 == id }
        } else if !values.contains(id) {
            values.append(id)
        }
        UserDefaults.standard.set(values, forKey: Key.disabledSources)
    }

    static func enableAllSources() {
        UserDefaults.standard.removeObject(forKey: Key.disabledSources)
    }

    /// 置顶/收藏的源；搜索时优先展示这些源的结果。
    static var pinnedSourceIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: Key.pinnedSources) ?? [] }
        set {
            var unique: [String] = []
            for id in newValue where !id.isEmpty && !unique.contains(id) {
                unique.append(id)
            }
            UserDefaults.standard.set(unique, forKey: Key.pinnedSources)
        }
    }

    static func isSourcePinned(_ id: String) -> Bool {
        return pinnedSourceIDs.contains(id)
    }

    static func setSource(_ id: String, pinned: Bool) {
        var values = pinnedSourceIDs
        if pinned {
            if !values.contains(id) {
                values.insert(id, at: 0)
            }
        } else {
            values.removeAll { $0 == id }
        }
        pinnedSourceIDs = values
    }

    static func toggleSourcePinned(_ id: String) -> Bool {
        let newValue = !isSourcePinned(id)
        setSource(id, pinned: newValue)
        return newValue
    }

    static var searchHistory: [String] {
        get { UserDefaults.standard.stringArray(forKey: Key.searchHistory) ?? [] }
        set {
            UserDefaults.standard.set(Array(newValue.prefix(12)), forKey: Key.searchHistory)
        }
    }

    static func addSearchHistory(_ keyword: String) {
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var history = searchHistory.filter { $0.caseInsensitiveCompare(value) != .orderedSame }
        history.insert(value, at: 0)
        searchHistory = history
    }

    static var dismissedCompliance: Bool {
        get { UserDefaults.standard.bool(forKey: Key.dismissedCompliance) }
        set { UserDefaults.standard.set(newValue, forKey: Key.dismissedCompliance) }
    }

    /// 默认开启连续播放；关闭时只解析当前集。
    static var continuousPlayback: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.continuousPlayback) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Key.continuousPlayback)
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.continuousPlayback) }
    }
}

// MARK: - Paths

enum OnlineSourcePaths {

    static var root: URL {
        let base: URL
        if let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            base = applicationSupport
        } else {
            base = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        }
        return base
            .appendingPathComponent("AniXPlayer", isDirectory: true)
            .appendingPathComponent("OnlineSources", isDirectory: true)
    }

    static var animekoFile: URL {
        return root.appendingPathComponent("animeko", isDirectory: true)
            .appendingPathComponent("css1.json")
    }

    static var kazumiDirectory: URL {
        return root.appendingPathComponent("kazumi", isDirectory: true)
    }

    static var kazumiIndexFile: URL {
        return kazumiDirectory.appendingPathComponent("index.json")
    }

    static var kazumiRulesDirectory: URL {
        return kazumiDirectory.appendingPathComponent("rules", isDirectory: true)
    }

    static func kazumiRuleFile(name: String) -> URL {
        return kazumiRulesDirectory.appendingPathComponent("\(name).json")
    }

    static func ensureDirectories() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: animekoFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(at: kazumiDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: kazumiRulesDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Load result

struct OnlineSourceLoadResult {
    let sources: [OnlineMediaSource]
    let warnings: [String]
}

// MARK: - Store

actor OnlineSourceStore {

    static let shared = OnlineSourceStore()

    private let cacheLifetime: TimeInterval = 7 * 24 * 60 * 60
    private var memoryCache: [OnlineMediaSource] = []

    private init() {}

    // MARK: Public

    func cachedSources() -> [OnlineMediaSource] {
        return memoryCache
    }

    func loadSources(
        forceRefresh: Bool = false,
        progress: ((String) -> Void)? = nil
    ) async throws -> OnlineSourceLoadResult {
        if !forceRefresh, !memoryCache.isEmpty, isCacheFresh() {
            return OnlineSourceLoadResult(sources: memoryCache, warnings: [])
        }

        try? OnlineSourcePaths.ensureDirectories()

        async let animeko = loadAnimeko(forceRefresh: forceRefresh, progress: progress)
        async let kazumi = loadKazumi(forceRefresh: forceRefresh, progress: progress)

        let animekoResult = await animeko
        let kazumiResult = await kazumi

        var sources = animekoResult.sources + kazumiResult.sources
        var warnings: [String] = []
        if let warning = animekoResult.warning { warnings.append(warning) }
        if let warning = kazumiResult.warning { warnings.append(warning) }

        // 源 id 去重；同名规则以后出现的为准。
        var seen = Set<String>()
        sources = sources.reversed().filter { seen.insert($0.id).inserted }.reversed()

        if sources.isEmpty {
            throw OnlinePlaybackError.noSources
        }

        memoryCache = sources
        return OnlineSourceLoadResult(sources: sources, warnings: warnings)
    }

    func clearCache() {
        memoryCache = []
        try? FileManager.default.removeItem(at: OnlineSourcePaths.root)
    }

    func clearKazumiCache() {
        memoryCache = memoryCache.filter { $0.engine != .kazumi }
        try? FileManager.default.removeItem(at: OnlineSourcePaths.kazumiDirectory)
    }

    func updateURLs(animeko: String, kazumi: String) {
        OnlineSourcePreferences.animekoURL = animeko
        OnlineSourcePreferences.kazumiURL = kazumi
        memoryCache = []
    }

    // MARK: Cache freshness

    private func isCacheFresh() -> Bool {
        let fileManager = FileManager.default
        var dates: [Date] = []
        if let attributes = try? fileManager.attributesOfItem(atPath: OnlineSourcePaths.animekoFile.path),
           let date = attributes[.modificationDate] as? Date {
            dates.append(date)
        }
        if let attributes = try? fileManager.attributesOfItem(atPath: OnlineSourcePaths.kazumiIndexFile.path),
           let date = attributes[.modificationDate] as? Date {
            dates.append(date)
        }
        guard !dates.isEmpty else { return false }
        let oldest = dates.min() ?? Date.distantPast
        return Date().timeIntervalSince(oldest) < cacheLifetime
    }

    // MARK: Animeko

    private struct EngineResult {
        let sources: [OnlineMediaSource]
        let warning: String?
    }

    private func loadAnimeko(forceRefresh: Bool, progress: ((String) -> Void)?) async -> EngineResult {
        let cacheURL = OnlineSourcePaths.animekoFile
        let cacheExists = FileManager.default.fileExists(atPath: cacheURL.path)
        let cacheFresh = isFresh(cacheURL)

        if !forceRefresh, cacheFresh,
           let data = try? Data(contentsOf: cacheURL),
           let sources = try? Self.parseAnimeko(data: data),
           !sources.isEmpty {
            return EngineResult(sources: sources, warning: nil)
        }

        progress?(NSLocalizedString("正在更新 Animeko 源…", comment: ""))
        guard let url = URL(string: OnlineSourcePreferences.animekoURL), url.host != nil else {
            if let data = try? Data(contentsOf: cacheURL),
               let sources = try? Self.parseAnimeko(data: data),
               !sources.isEmpty {
                return EngineResult(
                    sources: sources,
                    warning: NSLocalizedString("Animeko 源地址无效，已使用本地缓存。", comment: "")
                )
            }
            return EngineResult(sources: [], warning: NSLocalizedString("Animeko 源地址无效。", comment: ""))
        }

        do {
            let data = try await OnlineHTTPClient.shared.getData(url, headers: ["Accept": "application/json"])
            let sources = try Self.parseAnimeko(data: data)
            guard !sources.isEmpty else {
                throw OnlinePlaybackError.noSources
            }
            try Self.writeAtomically(data, to: cacheURL)
            return EngineResult(sources: sources, warning: nil)
        } catch {
            if let data = try? Data(contentsOf: cacheURL),
               let sources = try? Self.parseAnimeko(data: data),
               !sources.isEmpty {
                return EngineResult(
                    sources: sources,
                    warning: String(
                        format: NSLocalizedString("Animeko 源更新失败，已使用本地缓存：%@", comment: ""),
                        error.localizedDescription
                    )
                )
            }
            return EngineResult(
                sources: [],
                warning: String(
                    format: NSLocalizedString("Animeko 源加载失败：%@", comment: ""),
                    error.localizedDescription
                )
            )
        }
    }

    // MARK: Kazumi

    private struct KazumiIndexEntry {
        let name: String
        let version: String
    }

    private func loadKazumi(forceRefresh: Bool, progress: ((String) -> Void)?) async -> EngineResult {
        let indexURL = OnlineSourcePaths.kazumiIndexFile
        let cacheFresh = isFresh(indexURL)

        if !forceRefresh, cacheFresh {
            let sources = Self.parseKazumiRules()
            if !sources.isEmpty {
                return EngineResult(sources: sources, warning: nil)
            }
        }

        progress?(NSLocalizedString("正在更新 Kazumi 源索引…", comment: ""))
        let baseURLString = OnlineSourcePreferences.kazumiURL
        guard let baseURL = URL(string: baseURLString), baseURL.host != nil else {
            let sources = Self.parseKazumiRules()
            if !sources.isEmpty {
                return EngineResult(
                    sources: sources,
                    warning: NSLocalizedString("Kazumi 源地址无效，已使用本地缓存。", comment: "")
                )
            }
            return EngineResult(sources: [], warning: NSLocalizedString("Kazumi 源地址无效。", comment: ""))
        }

        var remoteWarning: String?
        var entries: [KazumiIndexEntry] = []

        do {
            let indexURLFull = baseURL.appendingPathComponent("index.json")
            let data = try await OnlineHTTPClient.shared.getData(indexURLFull, headers: ["Accept": "application/json"])
            entries = Self.parseKazumiIndex(data: data)
            guard !entries.isEmpty else {
                throw OnlinePlaybackError.emptyResponse
            }
            try Self.writeAtomically(data, to: indexURL)
        } catch {
            entries = (try? Data(contentsOf: indexURL)).map(Self.parseKazumiIndex) ?? []
            remoteWarning = String(
                format: NSLocalizedString("Kazumi 源索引更新失败：%@", comment: ""),
                error.localizedDescription
            )
            if entries.isEmpty {
                return EngineResult(sources: [], warning: remoteWarning)
            }
        }

        // 只下载版本变化的规则；单条失败不阻塞其他源。
        let total = entries.count
        for (index, entry) in entries.enumerated() {
            progress?(String(
                format: NSLocalizedString("正在更新 Kazumi 源 %d/%d…", comment: ""),
                index + 1,
                total
            ))

            let localFile = OnlineSourcePaths.kazumiRuleFile(name: entry.name)
            let localVersion = Self.readKazumiRuleVersion(at: localFile)
            if localVersion == entry.version, FileManager.default.fileExists(atPath: localFile.path) {
                continue
            }

            guard let ruleURL = Self.kazumiRuleURL(baseURL: baseURL, name: entry.name) else {
                continue
            }
            do {
                let data = try await OnlineHTTPClient.shared.getData(ruleURL, headers: ["Accept": "application/json"])
                try Self.writeAtomically(data, to: localFile)
            } catch {
                // 保留旧规则文件；没有旧文件时跳过该源。
                continue
            }
        }

        Self.removeUnknownKazumiRules(entries: entries)
        let sources = Self.parseKazumiRules()
        if sources.isEmpty, let remoteWarning {
            return EngineResult(sources: [], warning: remoteWarning)
        }
        return EngineResult(
            sources: sources,
            warning: sources.isEmpty ? NSLocalizedString("Kazumi 没有可用规则。", comment: "") : remoteWarning
        )
    }

    // MARK: Parsing - Animeko

    static func parseAnimeko(data: Data) throws -> [OnlineMediaSource] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OnlinePlaybackError.htmlParseFailed
        }

        let exported = (root["exportedMediaSourceDataList"] as? [String: Any])?["mediaSources"] as? [[String: Any]]
        let sources = exported ?? (root["mediaSources"] as? [[String: Any]]) ?? []
        guard !sources.isEmpty else {
            throw OnlinePlaybackError.noSources
        }

        return sources.enumerated().compactMap { index, raw -> OnlineMediaSource? in
            guard let arguments = raw["arguments"] as? [String: Any] else { return nil }
            let searchConfig = arguments["searchConfig"] as? [String: Any] ?? [:]
            let name = (arguments["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let searchURL = (searchConfig["searchUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, !searchURL.isEmpty else { return nil }

            let matchVideo = searchConfig["matchVideo"] as? [String: Any]
                ?? arguments["matchVideo"] as? [String: Any]
                ?? [:]
            let headers = Self.stringDictionary(matchVideo["addHeadersToVideo"])
            let userAgent = Self.headerValue(headers, keys: ["useragent", "user-agent"])
                ?? OnlineHTTPClient.defaultUserAgent
            let referer = Self.headerValue(headers, keys: ["referer", "referrer"])

            let selectorA = searchConfig["selectorSubjectFormatA"] as? [String: Any] ?? [:]
            let selectorIndexed = searchConfig["selectorSubjectFormatIndexed"] as? [String: Any] ?? [:]
            let channelFlattened = searchConfig["selectorChannelFormatFlattened"] as? [String: Any] ?? [:]
            let channelNoChannel = searchConfig["selectorChannelFormatNoChannel"] as? [String: Any] ?? [:]

            let subjectFormat = (searchConfig["subjectFormatId"] as? String) ?? "a"
            let channelFormat = (searchConfig["channelFormatId"] as? String) ?? "no-channel"

            let tier = (arguments["tier"] as? Int) ?? 0
            let detail = (arguments["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return OnlineMediaSource(
                id: "animeko:\(name)",
                engine: .animeko,
                name: name,
                detail: detail,
                iconURL: (arguments["iconUrl"] as? String).flatMap(URL.init(string:)),
                tier: tier,
                searchURL: searchURL,
                rawBaseURL: (searchConfig["rawBaseUrl"] as? String)?.nilIfEmpty,
                searchUseOnlyFirstWord: (searchConfig["searchUseOnlyFirstWord"] as? Bool) ?? false,
                searchRemoveSpecial: (searchConfig["searchRemoveSpecial"] as? Bool) ?? false,
                userAgent: userAgent,
                referer: referer?.nilIfEmpty,
                cookies: (matchVideo["cookies"] as? String)?.nilIfEmpty ?? "",
                subjectFormat: subjectFormat,
                subjectSelectLists: (selectorA["selectLists"] as? String) ?? "a",
                subjectSelectNames: (selectorIndexed["selectNames"] as? String) ?? "",
                subjectSelectLinks: (selectorIndexed["selectLinks"] as? String) ?? "",
                preferShorterName: (selectorA["preferShorterName"] as? Bool)
                    ?? (selectorIndexed["preferShorterName"] as? Bool)
                    ?? false,
                channelFormat: channelFormat,
                selectEpisodeLists: (channelFlattened["selectEpisodeLists"] as? String) ?? "",
                selectEpisodesFromList: (channelFlattened["selectEpisodesFromList"] as? String) ?? "",
                selectEpisodes: (channelNoChannel["selectEpisodes"] as? String) ?? "",
                matchEpisodeSortFromName: (channelFlattened["matchEpisodeSortFromName"] as? String)
                    ?? (channelNoChannel["matchEpisodeSortFromName"] as? String)
                    ?? "",
                showAllEpisodes: false,
                enableNestedURL: (matchVideo["enableNestedUrl"] as? Bool) ?? false,
                matchNestedURL: (matchVideo["matchNestedUrl"] as? String) ?? "",
                matchVideoURL: (matchVideo["matchVideoUrl"] as? String) ?? "",
                addHeadersToVideo: headers,
                kazumiSearchList: "",
                kazumiSearchName: "",
                kazumiSearchResult: "",
                kazumiChapterRoads: "",
                kazumiChapterResult: ""
            )
        }
    }

    // MARK: Parsing - Kazumi

    private static func parseKazumiIndex(data: Data) -> [KazumiIndexEntry] {
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { item in
            guard let name = (item["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return nil }
            let version = (item["version"] as? String) ?? ""
            return KazumiIndexEntry(name: name, version: version)
        }
    }

    private static func parseKazumiRules() -> [OnlineMediaSource] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: OnlineSourcePaths.kazumiRulesDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        var sources: [OnlineMediaSource] = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard file.pathExtension.lowercased() == "json",
                  let data = try? Data(contentsOf: file),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let source = parseKazumiRule(object, index: sources.count) else {
                continue
            }
            sources.append(source)
        }
        return sources
    }

    private static func parseKazumiRule(_ rule: [String: Any], index: Int) -> OnlineMediaSource? {
        let name = (rule["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let searchURL = (rule["searchURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let searchList = (rule["searchList"] as? String) ?? ""
        let searchName = (rule["searchName"] as? String) ?? ""
        let searchResult = (rule["searchResult"] as? String) ?? ""
        let chapterRoads = (rule["chapterRoads"] as? String) ?? ""
        let chapterResult = (rule["chapterResult"] as? String) ?? ""

        guard !name.isEmpty,
              !searchURL.isEmpty,
              !searchList.isEmpty,
              !searchResult.isEmpty,
              !chapterRoads.isEmpty,
              !chapterResult.isEmpty else {
            return nil
        }

        // Windows 版同样跳过 POST 与 API 模式规则。
        if (rule["usePost"] as? Bool) == true { return nil }
        if (rule["searchMode"] as? String)?.lowercased() == "api" { return nil }
        if (rule["chapterMode"] as? String)?.lowercased() == "api" { return nil }

        let baseURL = (rule["baseURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let referer = (rule["referer"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userAgent = (rule["userAgent"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        var detail = "Kazumi 规则"
        if let version = rule["version"] as? String, !version.isEmpty {
            detail += " · v\(version)"
        }
        if ((rule["antiCrawlerConfig"] as? [String: Any])?["enabled"] as? Bool) == true {
            detail += NSLocalizedString(" · 站点有反爬验证，可能无法搜索", comment: "")
        }

        var headers: [String: String] = [:]
        if let referer, !referer.isEmpty {
            headers["Referer"] = referer
        }
        if let userAgent, !userAgent.isEmpty {
            headers["User-Agent"] = userAgent
        }

        return OnlineMediaSource(
            id: "kazumi:\(name)",
            engine: .kazumi,
            name: name,
            detail: detail,
            iconURL: nil,
            tier: 100 + index,
            searchURL: searchURL,
            rawBaseURL: baseURL,
            searchUseOnlyFirstWord: false,
            searchRemoveSpecial: false,
            userAgent: (userAgent?.isEmpty == false ? userAgent! : OnlineHTTPClient.defaultUserAgent),
            referer: referer?.nilIfEmpty,
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
            addHeadersToVideo: headers,
            kazumiSearchList: searchList,
            kazumiSearchName: searchName,
            kazumiSearchResult: searchResult,
            kazumiChapterRoads: chapterRoads,
            kazumiChapterResult: chapterResult
        )
    }

    // MARK: File helpers

    private func isFresh(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attributes[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(date) < cacheLifetime
    }

    private static func readKazumiRuleVersion(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["version"] as? String
    }

    private static func removeUnknownKazumiRules(entries: [KazumiIndexEntry]) {
        let names = Set(entries.map { $0.name })
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: OnlineSourcePaths.kazumiRulesDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        for file in files where file.pathExtension.lowercased() == "json" {
            let name = file.deletingPathExtension().lastPathComponent
            if !names.contains(name) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private static func kazumiRuleURL(baseURL: URL, name: String) -> URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let base = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        return URL(string: "\(base)/\(encoded).json")
    }

    private static func writeAtomically(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: url)
        }
    }

    private static func stringDictionary(_ raw: Any?) -> [String: String] {
        guard let dictionary = raw as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            if let string = value as? String {
                result[key] = string
            } else if let number = value as? NSNumber {
                result[key] = number.stringValue
            }
        }
        return result
    }

    private static func headerValue(_ headers: [String: String], keys: [String]) -> String? {
        let lowered = keys.map { $0.lowercased() }
        for (key, value) in headers where lowered.contains(key.lowercased()) {
            return value
        }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
